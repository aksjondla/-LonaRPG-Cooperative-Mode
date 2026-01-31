#==============================================================================
# Cooperative Mode - Companion Control System
#==============================================================================
# Handles manual control of the companion by Player 2
# Disables companion AI when in manual control mode
#==============================================================================

module CompanionControl
  @@controlled_companion = nil
  @@debug_counter = 0
  @@original_move_type = nil
  
  # Find any active companion (type front or type back)
  def self.find_front_companion
    return nil unless $game_player
    
    begin
      companion_name_front = $game_player.record_companion_name_front rescue nil
      companion_name_back = $game_player.record_companion_name_back rescue nil
      
      return nil unless $game_map && $game_map.events
      
      companion = $game_map.events.values.find do |event|
        # Skip projectiles/missiles
        next if event.missile
        
        next unless event.respond_to?(:npc) && event.npc
        next unless event.npc.master == $game_player
        
        # Get name safely
        event_name = event.instance_variable_get(:@event).name rescue nil
        next if event_name.nil? || event_name.empty?
        
        # Check if name matches front or back companion
        event_name_matches = false
        if companion_name_front && event_name == companion_name_front
          event_name_matches = true
        elsif companion_name_back && event_name == companion_name_back
          event_name_matches = true
        end
        
        event_name_matches
      end
      
      # Debug output occasionally
      if companion && @@debug_counter % 300 == 0
        companion_name = companion.instance_variable_get(:@event).name rescue "Unknown"
        p "Companion: #{companion_name} at (#{companion.x},#{companion.y})"
      end
      @@debug_counter += 1
      
      companion
    rescue => e
      nil
    end
  end
  
  # Disable companion AI movement and combat
  def self.disable_companion_ai(companion)
    return unless companion
    return unless companion.respond_to?(:get_manual_move_type)
    
    if @@original_move_type.nil?
      @@original_move_type = companion.get_manual_move_type
      companion.set_manual_move_type(nil)
      
      # Clear AI target and reset state
      if companion.respond_to?(:npc) && companion.npc
        companion.npc.instance_variable_set(:@target, nil) if companion.npc.respond_to?(:target)
        companion.npc.instance_variable_set(:@alert_level, 0)
        companion.npc.instance_variable_set(:@ai_state, :none)
        companion.npc.instance_variable_set(:@aggro_frame, 0)
      end
      
      p "Companion AI disabled (movement + combat)"
    end
  end
  
  # Re-enable companion AI movement
  def self.enable_companion_ai(companion)
    return unless companion
    return unless companion.respond_to?(:set_manual_move_type)
    
    if @@original_move_type
      companion.set_manual_move_type(@@original_move_type)
      @@original_move_type = nil
      p "Companion AI enabled"
    end
  end
  
  # Main update loop
  def self.update
    begin
      # Always update input to detect F2 and F3
      CoopInput.update
      
      if CoopInput.trigger?(:force_enable)
        unless CoopConfig.enabled?
          companion = find_front_companion
          if companion
            CoopConfig.enable
            p "Co-op mode enabled! Press F2 to take control"
            CoopConfig.show_control_message(CoopTranslations.t(:coop_enabled))
          else
            p "No companion found. Hire a companion first."
            CoopConfig.show_control_message(CoopTranslations.t(:no_companion))
          end
        else
          p "Co-op already enabled"
          CoopConfig.show_control_message(CoopTranslations.t(:already_enabled))
        end
      end
      
      # Toggle control mode with F2
      if CoopInput.trigger?(:toggle_control)
        if CoopConfig.enabled?
          companion = find_front_companion
          
          if CoopConfig.manual_control?
            enable_companion_ai(companion) if companion
          else
            disable_companion_ai(companion) if companion
          end
          
          CoopConfig.toggle_control_mode
        else
          p "Coop not available - Use F3 to enable or hire a companion"
        end
      end
      
      return unless CoopConfig.enabled?
      return unless CoopConfig.manual_control?
      
      @@controlled_companion = find_front_companion
      
      if !@@controlled_companion && @@debug_counter % 300 == 0
        p "WARNING: No companion found"
      end
      
      return unless @@controlled_companion
      
      update_companion_movement
      update_companion_actions
    rescue => e
      p "CompanionControl ERROR: #{e.message}"
    end
  end
  
  # Handle companion movement
  def self.update_companion_movement
    return if @@controlled_companion.moving?
    
    direction = CoopInput.get_direction
    
    if direction != 0
      if @@debug_counter % 60 == 0
        p "Direction: #{direction}, moving..."
      end
      
      @@controlled_companion.move_straight(direction)
    end
  end
  
  def self.update_companion_actions
    if CoopInput.trigger?(:skill1)
      perform_companion_attack(0)
    end
    
    if CoopInput.trigger?(:skill2)
      perform_companion_attack(1)
    end
    
    if CoopInput.trigger?(:skill3)
      perform_companion_attack(2)
    end
    
    if CoopInput.trigger?(:skill4)
      perform_companion_attack(3)
    end
    
    if CoopInput.trigger?(:skill5)
      perform_companion_attack(4)
    end
    
    if CoopInput.trigger?(:skill6)
      perform_companion_attack(5)
    end
    
    if CoopInput.trigger?(:dodge)
      perform_companion_dodge
    end
  end
  
  def self.perform_companion_attack(skill_index = 0)
    begin
      return unless @@controlled_companion
      return unless @@controlled_companion.respond_to?(:npc)
      
      npc = @@controlled_companion.npc
      return unless npc
      return if npc.action_state == :skill  # Already attacking
      
      skills_list = npc.skills_killer rescue []
      
      skill = skills_list[skill_index] if skills_list && skill_index < skills_list.length
      
      return unless skill
      
      # Block projectiles due to bug which crashes the game
      if defined?($data_arpgskills)
        blocked_projectiles = [
          $data_arpgskills["NpcCurvedNecroMissile"],
          $data_arpgskills["NpcNecroMissile"],
          $data_arpgskills["NpcFireBall"],
          $data_arpgskills["NpcIceBall"]
        ].compact
        
        blocked = blocked_projectiles.include?(skill)
        blocked = true if !blocked && back_companion? && ranged_skill?(skill)
        
        if blocked
          if $game_map && $game_map.interpreter
            $game_map.interpreter.call_msg_popup(CoopTranslations.t(:projectile_blocked)) rescue nil
          end
          @@controlled_companion.call_balloon(6, 30) rescue nil
          return
        end
      end
      
      begin
        npc.launch_skill(skill, true)
      rescue NoMethodError, ArgumentError, NameError => e
      rescue => skill_error
      end
      
    rescue => e
      print "Companion attack error: #{e.message}\n" if defined?($DEBUG_COOP_MOD)
    end
  end
  
  # True if the controlled companion is a BACK slot companion
  def self.back_companion?
    return false unless @@controlled_companion && $game_player
    companion_name_back = $game_player.record_companion_name_back rescue nil
    return false if companion_name_back.nil? || companion_name_back.empty?
    event_name = @@controlled_companion.instance_variable_get(:@event).name rescue nil
    return false if event_name.nil?
    event_name == companion_name_back
  end
  
  # True if skill is ranged/projectile (summon_user creates a projectile entity)
  def self.ranged_skill?(skill)
    return false unless skill
    su = skill.respond_to?(:summon_user) ? skill.summon_user : nil
    return false if su.nil? || su.to_s.empty?
    su.to_s =~ /Projectile|Missile/i ? true : false
  end
  
  # Attempt to find nearby enemy within range for projectile skills, currently not used
  def self.find_nearby_enemy(companion, range = 10)
    return nil unless companion && $game_map
    
    begin
      comp_x = companion.x
      comp_y = companion.y
      
      $game_map.events.values.each do |event|
        next if event.missile
        
        next unless event.respond_to?(:npc) && event.npc
        next if event.npc.action_state == :death
        next if event.npc.master == $game_player 
        
        distance = (event.x - comp_x).abs + (event.y - comp_y).abs
        
        return event if distance <= range
      end
    rescue => e
    end
    
    nil
  end
  
  # Execute companion dodge
  def self.perform_companion_dodge
    return unless @@controlled_companion
    return unless @@controlled_companion.respond_to?(:map_token)
    
    token = @@controlled_companion.map_token
    token.perform_dodge if token && token.respond_to?(:perform_dodge)
  end
end

#==============================================================================
# Game_Event Hook - Disable AI during manual control
#==============================================================================

class Game_Event < Game_Character
  alias_method :coop_original_update_self_movement, :update_self_movement unless method_defined?(:coop_original_update_self_movement)
  
  def update_self_movement
    return coop_original_update_self_movement if @missile
    
    return coop_original_update_self_movement unless @event
    
    begin
      if CoopConfig.manual_control? && $game_player
        companion_name_front = $game_player.record_companion_name_front rescue nil
        companion_name_back = $game_player.record_companion_name_back rescue nil
        
        event_name = @event.name rescue nil
        
        if event_name && ((companion_name_front && event_name == companion_name_front) ||
           (companion_name_back && event_name == companion_name_back))
          return
        end
      end
    rescue => e
    end
    
    coop_original_update_self_movement
  end
  
  # Hook to block AI combat sensor when under manual control
  alias_method :coop_original_update_npc_sensor, :update_npc_sensor unless method_defined?(:coop_original_update_npc_sensor)
  
  def update_npc_sensor
    return coop_original_update_npc_sensor if @missile
    
    return coop_original_update_npc_sensor unless @event
    
    begin
      if CoopConfig.manual_control? && $game_player
        is_controlled = false
        
        if self.respond_to?(:npc) && self.npc && self.npc.master == $game_player
          is_controlled = true
        end
        
        return if is_controlled
      end
    rescue => e
    end
    
    coop_original_update_npc_sensor
  end
end

#==============================================================================
# Scene_Map Hook - Update control system each frame
#==============================================================================

class Scene_Map
  alias_method :coop_original_update, :update unless method_defined?(:coop_original_update)
  
  @@coop_update_count = 0
  
  def update
    coop_original_update
    CompanionControl.update
    
    @@coop_update_count += 1
    if @@coop_update_count == 1
      p "CoopMode: Scene_Map update hook is working"
    end
  end
end

#==============================================================================
# Game_Player Hook - Auto-enable on companion hire/dismiss
#==============================================================================

class Game_Player
  alias_method :coop_original_set_companion_front, :record_companion_name_front= unless method_defined?(:coop_original_set_companion_front)
  
  def record_companion_name_front=(name)
    coop_original_set_companion_front(name)
    
    # Auto-enable when companion is hired
    if name && !name.empty?
      unless CoopConfig.enabled?
        CoopConfig.enable
        p "Companion (front) hired! Player 2 can control it with F2"
        CoopConfig.show_control_message(CoopTranslations.t(:coop_enabled))
      end
    else
      # Disable if no other companions
      if CoopConfig.enabled? && (!self.record_companion_name_back || self.record_companion_name_back.empty?)
        CoopConfig.disable
        p "All companions dismissed. Co-op control disabled."
      end
    end
  end
  
  alias_method :coop_original_set_companion_back, :record_companion_name_back= unless method_defined?(:coop_original_set_companion_back)
  
  def record_companion_name_back=(name)
    coop_original_set_companion_back(name)
    
    if name && !name.empty?
      unless CoopConfig.enabled?
        CoopConfig.enable
        p "Companion (back) hired! Player 2 can control it with F2"
        CoopConfig.show_control_message(CoopTranslations.t(:coop_enabled))
      end
    else
      if CoopConfig.enabled? && (!self.record_companion_name_front || self.record_companion_name_front.empty?)
        CoopConfig.disable
        p "All companions dismissed. Co-op control disabled."
      end
    end
  end
end

#==============================================================================
# Console Commands
#==============================================================================

def toggle_coop
  if CoopConfig.enabled?
    CoopConfig.toggle_control_mode
  else
    p "Co-op not enabled. Use force_enable_coop first or hire a companion."
  end
end

def force_enable_coop
  CoopConfig.enable
  p "Co-op mode force enabled"
end

def disable_coop
  CoopConfig.disable
  p "Co-op mode disabled"
end

def coop_status
  p "====== COOP STATUS ======"
  p "Enabled: #{CoopConfig.enabled?}"
  p "Mode: #{CoopConfig.get_control_mode}"
  p "Manual: #{CoopConfig.manual_control?}"
  
  if $game_player && $game_player.respond_to?(:record_companion_name_front)
    cname = $game_player.record_companion_name_front
    p "Companion: #{cname || 'None'}"
  else
    p "Companion system N/A"
  end
  
  comp = CompanionControl.find_front_companion
  p "Found: #{!comp.nil?}"
  p "======================="
  
  # Show in game
  if $game_map && $game_map.interpreter
    mode = CoopConfig.get_control_mode
    msg = "Coop: #{CoopConfig.enabled? ? 'ON' : 'OFF'} | #{mode}"
    $game_map.interpreter.call_msg_popup(msg) rescue nil
  end
  
  return "OK"
end

def test_coop_input
  print "Testing coop input system...\n"
  print "Press F2 now...\n"
  CoopInput.class_variable_set(:@@debug_mode, true)
  return "Test mode activated"
end

def test_coop_simple
  print "=== COOP MOD TEST ===\n"
  print "Mod is loaded and working!\n"
  
  if $game_map && $game_map.interpreter
    $game_map.interpreter.call_msg_popup("Coop mod works!") rescue nil
  end
  
  return "Test completed"
end

def coop_toggle_now
  p "Toggling coop..."
  if CoopConfig.enabled?
    CoopConfig.toggle_control_mode
    mode = CoopConfig.get_control_mode
    p "Mode: #{mode}"
    return "#{mode}"
  else
    p "Not enabled - hire companion first"
    return "Not enabled"
  end
end

def test_input_detection
  begin
    p "INPUT TEST - Debug ON"
    p "Press I/J/K/L keys now"
    CoopInput.class_variable_set(:@@debug_mode, true)
    return "Debug ON"
  rescue => e
    p "Error: #{e.message}"
    return "Error"
  end
end

def test_input_off
  CoopInput.class_variable_set(:@@debug_mode, false)
  p "Debug OFF"
  return "Debug OFF"
end

def test_y_key
  msg = "Y KEY TEST: Command works!"
  print msg + "\n"
  
  # Show visual confirmation
  if $game_map && $game_map.interpreter
    $game_map.interpreter.call_msg_popup("Test OK - Press Y now")
  end
  
  # Enable debug
  CoopInput.class_variable_set(:@@debug_mode, true) rescue nil
  
  # debug indicator when Y is pressed
  @@y_key_test_mode = true
  
  msg
end

def test_check_update
  count = CompanionControl.class_variable_get(:@@debug_counter) rescue 0
  "Update running: #{count} frames"
end

def show_companion_skills #not working right now
  begin
    return "No player" unless $game_player
    
    # Find companion
    companion_name = $game_player.record_companion_name_front rescue nil
    return "No companion hired" if !companion_name || companion_name.empty?
    
    # Search in map
    companion = $game_map.events.values.find do |event|
      next unless event.respond_to?(:npc) && event.npc
      next unless event.npc.master == $game_player
      event
    end
    
    return "Companion not found" unless companion
    
    npc = companion.npc
    return "No NPC" unless npc
    
    # Get skill list
    skills_list = npc.skills_killer rescue []
    
    if skills_list.nil? || skills_list.empty?
      return "No skills available"
    end
    
    companion_name = companion.instance_variable_get(:@event).name rescue "Unknown"
    print "=== COMPANION SKILLS ===\n"
    print "Companion: #{companion_name}\n"
    print "Available skills (#{skills_list.length}):\n"
    
    skills_list.each_with_index do |skill, index|
      if skill
        key = case index
              when 0 then "Y"
              when 1 then "4"
              when 2 then "5"
              else "N/A"
              end
        print "  [#{key}] Skill #{index + 1}: #{skill.name rescue 'Unknown'}\n"
      end
    end
    
    "OK - Check console"
  rescue => e
    "ERROR: #{e.message}"
  end
end

def test_attack_now
  begin
    return "No player" unless $game_player
    
    companion_name = $game_player.record_companion_name_front rescue nil
    return "No companion name" if !companion_name || companion_name.empty?
    
    companion = $game_map.events.values.find do |event|
      next unless event.respond_to?(:npc) && event.npc
      next unless event.npc.master == $game_player
      event
    end
    
    return "Companion not found" unless companion
    
    npc = companion.npc
    return "No NPC" unless npc
    
    skill = npc.skill || ($data_arpgskills["BasicNormal"] rescue nil)
    return "No skill available" unless skill
    
    print "Launching attack...\n"
    result = npc.launch_skill(skill, false)
    $game_map.interpreter.call_msg_popup("Attack launched!") if $game_map && $game_map.interpreter
    
    "SUCCESS: Attack executed (#{skill.class.name})"
  rescue => e
    "ERROR: #{e.message}"
  end
end

def check_companion
  begin
    p "=== COMPANION CHECK ==="
    
    if !$game_player
      p "ERROR: No player"
      return "No player"
    end
    
    companion_name = $game_player.record_companion_name_front rescue nil
    p "Companion name: #{companion_name.inspect}"
    
    if !companion_name || companion_name.empty?
      p "No companion hired"
      return "No companion"
    end
    
    p "Searching in #{$game_map.events.size} events..."
    
    $game_map.events.each do |event_id, event|
      # skip projectiles/missiles
      next if event.missile
      
      event_name = event.instance_variable_get(:@event).name rescue nil
      next if event_name.nil? || event_name.empty?
      
      if event_name == companion_name
        p "FOUND EVENT: ID=#{event_id}, Name=#{event_name}"
        p "Position: (#{event.x},#{event.y})"
        p "Is missile: #{event.missile}"
        
        p "Moving down..."
        event.move_straight(2)
        p "Move sent!"
        
        $game_map.interpreter.call_msg_popup("Found & moved!") rescue nil
        return "OK"
      end
    end
    
    p "ERROR: Not found in map"
    return "Not found"
    
  rescue => e
    p "ERROR: #{e.message}"
    p e.backtrace[0]
    return "Error"
  end
end
