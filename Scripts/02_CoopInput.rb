#==============================================================================
# Cooperative Mode - Input Handler
#==============================================================================
# Captures alternative keyboard inputs for Player 2
# Uses Windows API for key detection
#==============================================================================

#==============================================================================
# Cooperative Mode - Named Pipe input bridge (Host -> Ruby)
#==============================================================================
# Receives snapshots from the C# Host over a named pipe.
# Packet format (inside the pipe frame):
#   [4B magic "LCO1"][1B version][1B count][2B reserved]
#   repeated records (16 bytes):
#     pid(u16), npc(u16), seq(u32), keysLo(u32), keysHi(u32)
# Pipe framing:
#   [u16 length][payload...]
#==============================================================================

module CoopPipe
  PIPE_NAME = "\\\\.\\pipe\\LCOInput"
  MAGIC = "LCO1"
  VERSION = 1
  MAX_READ = 16384
  TIMEOUT_FRAMES = 10
  DEBUG = false
  DEBUG_EVERY = 30

  GENERIC_READ = 0x80000000
  OPEN_EXISTING = 3
  FILE_ATTRIBUTE_NORMAL = 0x80
  INVALID_HANDLE_VALUE = 0xFFFFFFFF

  @@handle = nil
  @@buf = ""
  @@last_packet_frame = -1
  @@players = {}
  @@active_pid = nil
  @@logged_connected = false
  @@debug_counter = 0
  @@last_bytes_read = 0
  @@last_packets_parsed = 0
  @@last_mask = 0
  @@last_seq = 0

  @@create_file = Win32API.new('kernel32', 'CreateFileA', 'PLLPLLL', 'L')
  @@read_file = Win32API.new('kernel32', 'ReadFile', 'LPLPP', 'I')
  @@peek_pipe = Win32API.new('kernel32', 'PeekNamedPipe', 'LPLPPP', 'I')
  @@wait_pipe = Win32API.new('kernel32', 'WaitNamedPipeA', 'PL', 'I')
  @@close_handle = Win32API.new('kernel32', 'CloseHandle', 'L', 'I')

  def self.connect
    return if @@handle

    @@wait_pipe.call(PIPE_NAME, 0) rescue nil
    handle = @@create_file.call(PIPE_NAME, GENERIC_READ, 0, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0)
    if handle == INVALID_HANDLE_VALUE || handle == -1 || handle == 0
      @@handle = nil
    else
      @@handle = handle
      @@buf = ""
      unless @@logged_connected
        p "CoopPipe: connected to #{PIPE_NAME}"
        @@logged_connected = true
      end
    end
  rescue => e
    @@handle = nil
  end

  def self.disconnect
    if @@handle
      @@close_handle.call(@@handle) rescue nil
    end
    @@handle = nil
    @@buf = ""
    @@logged_connected = false
  end

  def self.poll
    connect if @@handle.nil?
    return unless @@handle

    read_available
    parse_buffer
    debug_log
  end

  def self.read_available
    @@last_bytes_read = 0
    loop do
      avail = [0].pack('L')
      dummy = "\0"
      read = [0].pack('L')

      ok = @@peek_pipe.call(@@handle, dummy, 1, read, avail, 0)
      if ok == 0
        disconnect
        return
      end

      bytes_avail = avail.unpack('L')[0]
      break if bytes_avail <= 0

      to_read = [bytes_avail, MAX_READ].min
      buf = "\0" * to_read
      read = [0].pack('L')
      ok = @@read_file.call(@@handle, buf, to_read, read, 0)
      if ok == 0
        disconnect
        return
      end

      count = read.unpack('L')[0]
      break if count <= 0

      @@buf << buf[0, count]
      @@last_bytes_read += count
    end
  rescue => e
    disconnect
  end

  def self.parse_buffer
    @@last_packets_parsed = 0
    loop do
      break if @@buf.bytesize < 2
      len = @@buf.unpack('v')[0]
      break if @@buf.bytesize < (2 + len)
      payload = @@buf[2, len]
      @@buf = @@buf[(2 + len)..-1] || ""
      apply_snapshot(payload)
      @@last_packets_parsed += 1
    end
  end

  def self.apply_snapshot(data)
    return if data.nil? || data.bytesize < 8
    return unless data[0, 4] == MAGIC

    ver = data.getbyte(4)
    return unless ver == VERSION

    count = data.getbyte(5)
    off = 8
    now = current_frame
    players = {}

    count.times do
      break if off + 16 > data.bytesize
      pid, npc, seq, lo, hi = data[off, 16].unpack('vvVVV')
      off += 16
      mask = lo | (hi << 32)
      players[pid] = { npc: npc, seq: seq, mask: mask, seen: now }
    end

    @@players = players
    @@last_packet_frame = now
    if players.size > 0
      if @@active_pid.nil? || !players.key?(@@active_pid)
        @@active_pid = players.keys.min
      end
    end

    if @@active_pid && @@players[@@active_pid]
      @@last_mask = @@players[@@active_pid][:mask] || 0
      @@last_seq = @@players[@@active_pid][:seq] || 0
    end
  end

  def self.active?
    return false if @@last_packet_frame < 0
    now = current_frame
    (now - @@last_packet_frame) <= TIMEOUT_FRAMES
  end

  def self.connected?
    !@@handle.nil?
  end

  def self.mask(pid = nil)
    return 0 unless active?
    return 0 if @@players.nil? || @@players.empty?
    if pid && @@players[pid]
      @@players[pid][:mask] || 0
    else
      if @@active_pid && @@players[@@active_pid]
        @@players[@@active_pid][:mask] || 0
      else
        0
      end
    end
  end

  def self.active_pid
    @@active_pid
  end

  def self.players
    @@players || {}
  end

  def self.set_active_pid(pid)
    @@active_pid = pid
  end

  def self.current_frame
    if defined?(Graphics) && Graphics.respond_to?(:frame_count)
      Graphics.frame_count
    else
      0
    end
  end

  def self.debug_log
    return unless DEBUG
    @@debug_counter += 1
    return unless (@@debug_counter % DEBUG_EVERY) == 0

    frame = current_frame
    connected = connected? ? "yes" : "no"
    active = active? ? "yes" : "no"
    pid = @@active_pid || 0
    mask_hex = sprintf("0x%016X", @@last_mask)
    seq = @@last_seq
    buf_size = @@buf.bytesize
    players_count = @@players ? @@players.size : 0
    p "CoopPipe dbg frame=#{frame} conn=#{connected} act=#{active} read=#{@@last_bytes_read} buf=#{buf_size} pkts=#{@@last_packets_parsed} players=#{players_count} pid=#{pid} seq=#{seq} mask=#{mask_hex}"
  end
end

module CoopInput
  NET_BITS = {
    up: 0,
    left: 1,
    down: 2,
    right: 3,
    dodge: 4,
    skill1: 8,
    skill2: 9,
    skill3: 10,
    skill4: 11,
    skill5: 12,
    skill6: 13,
    skill_grab: 14,
    cycle_companion: 15
  }

  VK_CODES = {
    A: 0x41, B: 0x42, C: 0x43, D: 0x44, E: 0x45, F: 0x46, G: 0x47, H: 0x48,
    I: 0x49, J: 0x4A, K: 0x4B, L: 0x4C, M: 0x4D, N: 0x4E, O: 0x4F, P: 0x50,
    Q: 0x51, R: 0x52, S: 0x53, T: 0x54, U: 0x55, V: 0x56, W: 0x57, X: 0x58,
    Y: 0x59, Z: 0x5A,
    NUM0: 0x30, NUM1: 0x31, NUM2: 0x32, NUM3: 0x33, NUM4: 0x34,
    NUM5: 0x35, NUM6: 0x36, NUM7: 0x37, NUM8: 0x38, NUM9: 0x39,
    F1: 0x70, F2: 0x71, F3: 0x72, F4: 0x73, F5: 0x74, F6: 0x75,
    F7: 0x76, F8: 0x77, F9: 0x78, F10: 0x79, F11: 0x7A, F12: 0x7B,
    NUMPAD0: 0x60, NUMPAD1: 0x61, NUMPAD2: 0x62, NUMPAD3: 0x63, NUMPAD4: 0x64,
    NUMPAD5: 0x65, NUMPAD6: 0x66, NUMPAD7: 0x67, NUMPAD8: 0x68, NUMPAD9: 0x69,
    SPACE: 0x20, ENTER: 0x0D, ESC: 0x1B, TAB: 0x09, BACKSPACE: 0x08,
    SHIFT: 0x10, CTRL: 0x11, ALT: 0x12,
    LEFT_ARROW: 0x25, UP_ARROW: 0x26, RIGHT_ARROW: 0x27, DOWN_ARROW: 0x28
  }

  def self.get_vk_code(key_symbol)
    VK_CODES[key_symbol] || VK_CODES[key_symbol.to_s.to_sym]
  end

  @@get_async_key_state = nil
  @@use_win32 = false
  @@key_states = {}
  @@prev_states = {}
  @@debug_mode = false
  @@initialized = false

  def self.initialize_input
    return if @@initialized
    @@initialized = true

    begin
      @@get_async_key_state = Win32API.new('user32', 'GetAsyncKeyState', 'i', 'i')
      @@use_win32 = true
      p "CoopInput: Win32API initialized successfully"
    rescue => e
      @@use_win32 = false
      p "CoopInput: Win32API not available - #{e.message}"
      p "CoopInput: Using fallback input system"
    end
  end

  def self.update
    initialize_input unless @@initialized

    CoopPipe.poll
    if CoopPipe.connected?
      update_from_network
    else
      update_from_local
    end
  rescue => e
    p "CoopInput: Error in update - #{e.message}"
  end

  def self.update_from_network
    keys = CoopConfig.keys
    mask = CoopPipe.mask

    keys.each do |action, key_symbol|
      @@prev_states[key_symbol] = @@key_states[key_symbol] || false
      bit = NET_BITS[action]
      if bit
        @@key_states[key_symbol] = ((mask >> bit) & 1) == 1
      elsif @@use_win32 && @@get_async_key_state
        vk_code = get_vk_code(key_symbol)
        if vk_code
          @@key_states[key_symbol] = (@@get_async_key_state.call(vk_code) & 0x8000) != 0
        else
          @@key_states[key_symbol] = false
        end
      else
        @@key_states[key_symbol] = false
      end
    end
  end

  def self.apply_network_mask(mask, prev_mask = nil)
    keys = CoopConfig.keys
    keys.each do |action, key_symbol|
      bit = NET_BITS[action]
      if bit
        current = ((mask >> bit) & 1) == 1
        previous = prev_mask ? (((prev_mask >> bit) & 1) == 1) : (@@key_states[key_symbol] || false)
        @@prev_states[key_symbol] = previous
        @@key_states[key_symbol] = current
      else
        @@prev_states[key_symbol] = @@key_states[key_symbol] || false
        @@key_states[key_symbol] = false
      end
    end
  end

  def self.update_from_local
    if @@use_win32 && @@get_async_key_state
      keys = CoopConfig.keys

      keys.each do |action, key_symbol|
        @@prev_states[key_symbol] = @@key_states[key_symbol] || false
        vk_code = get_vk_code(key_symbol)
        if vk_code
          @@key_states[key_symbol] = (@@get_async_key_state.call(vk_code) & 0x8000) != 0
        end
      end
    else
      toggle_key = CoopConfig.keys[:toggle_control]
      @@prev_states[toggle_key] = @@key_states[toggle_key] || false
      @@key_states[toggle_key] = Input.trigger?(:F5)
    end
  end

  def self.press?(key)
    mapped_key = CoopConfig.keys[key]
    return false unless mapped_key
    @@key_states[mapped_key] || false
  end

  def self.trigger?(key)
    mapped_key = CoopConfig.keys[key]
    return false unless mapped_key
    current = @@key_states[mapped_key] || false
    previous = @@prev_states[mapped_key] || false
    result = current && !previous

    if result && @@debug_mode
      p "CoopInput: #{key} triggered (mapped to #{mapped_key})"
    end

    result
  end

  def self.repeat?(key)
    press?(key)
  end

  def self.get_direction
    return 0 unless CoopConfig.manual_control?

    return 8 if press?(:up)
    return 2 if press?(:down)
    return 4 if press?(:left)
    return 6 if press?(:right)
    return 0
  end
end
