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
  @@last_reported_target = nil  # for "Objetivo válido obtenido" message (avoid spam)
  @@projectile_no_target_balloon_shown = false  # show "?" only once until they get a target
  @@companion_index = 0  # 0 = front, 1 = back; Player 2 cycles with cycle_companion key
  
  # Returns the companion event at slot index (0 = front, 1 = back), or nil if none at that slot.
  def self.find_companion_at_index(index)
    return nil unless $game_player && $game_map && $game_map.events
    name = (index == 0) ? ($game_player.record_companion_name_front rescue nil) : ($game_player.record_companion_name_back rescue nil)
    return nil if name.nil? || name.empty?
    $game_map.events.values.find do |event|
      next if event.missile
      next unless event.respond_to?(:npc) && event.npc && event.npc.master == $game_player
      event_name = event.instance_variable_get(:@event).name rescue nil
      event_name == name
    end
  end
  
  # Currently selected companion for Player 2 control (by index). Falls back to other slot if current has none.
  def self.find_front_companion
    return nil unless $game_player
    @@debug_counter += 1
    c = find_companion_at_index(@@companion_index)
    if c.nil?
      other = @@companion_index == 0 ? 1 : 0
      c = find_companion_at_index(other)
      @@companion_index = other if c
    end
    c
  rescue => e
    nil
  end
  
  # Expose for hooks: the one companion Player 2 is controlling this frame.
  def self.controlled_companion_event
    @@controlled_companion
  end
  
  # Disable companion AI movement (targeting is left to the AI so companion can get @target for projectiles)
  def self.disable_companion_ai(companion)
    return unless companion
    return unless companion.respond_to?(:get_manual_move_type)
    
    if @@original_move_type.nil?
      @@original_move_type = companion.get_manual_move_type
      companion.set_manual_move_type(nil)
      # Do NOT clear @target: we let the AI handle targeting so the companion can acquire a valid target for projectile skills.
      # Only block movement; update_npc_sensor still runs so sense_target can set @target.
    end
  end
  
  # Re-enable companion AI movement
  def self.enable_companion_ai(companion)
    return unless companion
    return unless companion.respond_to?(:set_manual_move_type)
    
    if @@original_move_type
      companion.set_manual_move_type(@@original_move_type)
      @@original_move_type = nil
      @@last_reported_target = nil
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
            CoopConfig.show_control_message(CoopTranslations.t(:coop_enabled))
          else
            CoopConfig.show_control_message(CoopTranslations.t(:no_companion))
          end
        else
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
          CoopConfig.show_control_message(CoopTranslations.t(:no_companion))
        end
      end
      
      return unless CoopConfig.enabled?
      return unless CoopConfig.manual_control?
      
      @@controlled_companion = find_front_companion
      
      # Cycle which companion Player 2 controls (F4 by default)
      if @@controlled_companion && CoopInput.trigger?(:cycle_companion)
        old_companion = @@controlled_companion
        @@companion_index = (@@companion_index + 1) % 2
        new_companion = find_companion_at_index(@@companion_index)
        if new_companion.nil?
          @@companion_index = (@@companion_index + 1) % 2
          new_companion = find_companion_at_index(@@companion_index)
        end
        if new_companion && old_companion != new_companion
          enable_companion_ai(old_companion)
          disable_companion_ai(new_companion)
          @@controlled_companion = new_companion
        end
        if new_companion && $game_map && $game_map.interpreter
          slot_name = (@@companion_index == 0) ? CoopTranslations.t(:slot_front) : CoopTranslations.t(:slot_back)
          msg = (CoopTranslations.t(:controlling).to_s.gsub(":", "").strip + " " + slot_name.to_s).strip
          $game_map.interpreter.call_msg_popup(msg) rescue nil
        end
      end
      return unless @@controlled_companion
      
      update_companion_movement
      update_companion_actions
      update_companion_target_message
      suppress_no_target_balloon
    rescue => e
    end
  end
  
  # Stop the game from showing "?" (balloon 2) repeatedly when companion has no target (alert_level 1 from sensor).
  def self.suppress_no_target_balloon
    return unless @@controlled_companion
    return unless @@controlled_companion.respond_to?(:npc) && @@controlled_companion.npc
    npc = @@controlled_companion.npc
    tgt = npc.instance_variable_get(:@target) rescue nil
    return if tgt && !(tgt.respond_to?(:deleted?) && tgt.deleted?) &&
              !(tgt.respond_to?(:actor) && tgt.actor && tgt.actor.action_state == :death)
    # No valid target: clear balloon 2 so "?" doesn't repeat from game's alert_level 1
    if @@controlled_companion.balloon_id == 2
      @@controlled_companion.balloon_id = 0
    end
    npc.instance_variable_set(:@balloon, 0) if npc.instance_variable_get(:@balloon) == 2
  end
  
  # Handle companion movement
  def self.update_companion_movement
    return if @@controlled_companion.moving?
    
    direction = CoopInput.get_direction
    
    if direction != 0
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
  
  # When the AI has given the companion a valid target, show "Objetivo válido obtenido" once per target.
  def self.update_companion_target_message
    return unless @@controlled_companion
    return unless @@controlled_companion.respond_to?(:npc) && @@controlled_companion.npc
    
    npc = @@controlled_companion.npc
    tgt = npc.instance_variable_get(:@target) rescue nil
    if tgt.nil?
      @@last_reported_target = nil
      return
    end
    return if tgt.respond_to?(:deleted?) && tgt.deleted?
    return if tgt.respond_to?(:actor) && tgt.actor && tgt.actor.action_state == :death
    
    return if @@last_reported_target == tgt
    @@last_reported_target = tgt
    @@projectile_no_target_balloon_shown = false  # allow "?" again if they lose target later
    if $game_map && $game_map.interpreter
      $game_map.interpreter.call_msg_popup(CoopTranslations.t(:target_acquired)) rescue nil
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
      
      # Projectile/ranged skills need a valid @target (set by AI) or the game can crash.
      # Allow all ranged skills (Cocona, Musketeer, etc.) when the companion has a target.
      if ranged_skill?(skill)
        tgt = npc.instance_variable_get(:@target) rescue nil
        if tgt.nil? || (tgt.respond_to?(:deleted?) && tgt.deleted?) ||
           (tgt.respond_to?(:actor) && tgt.actor && tgt.actor.action_state == :death)
          unless @@projectile_no_target_balloon_shown
            @@projectile_no_target_balloon_shown = true
            if $game_map && $game_map.interpreter
              $game_map.interpreter.call_msg_popup(CoopTranslations.t(:projectile_needs_target)) rescue nil
            end
            @@controlled_companion.call_balloon(2, 0) rescue nil  # 0 = single show, not 30 seconds repeat
          end
          return
        end
      end

      # Limit summon undead (e.g. Cocona skeletons) to 5 active to avoid game crash
      if summon_undead_skill?(skill) && count_active_undead_for(@@controlled_companion) >= 5
        if $game_map && $game_map.interpreter
          $game_map.interpreter.call_msg_popup(CoopTranslations.t(:max_skeletons)) rescue nil
        end
        @@controlled_companion.call_balloon(2, 0) rescue nil
        return
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
  
  def self.ranged_skill?(skill)
    return false unless skill
    su = skill.respond_to?(:summon_user) ? skill.summon_user : nil
    return false if su.nil? || su.to_s.empty?
    su = su.to_s
    return true if su =~ /Projectile|Missile/i
    return true if su =~ /EffectNpcCasting|EffectNpcGunBrust/i
    false
  end

  def self.summon_undead_skill?(skill)
    return false unless skill && defined?($data_arpgskills)
    summon_skills = [
      $data_arpgskills["NpcCurvedSummonUndeadWarrior"],
      $data_arpgskills["NpcCurvedSummonUndeadBow"]
    ].compact
    summon_skills.include?(skill)
  end

  # Count active undead (skeletons) summoned by this companion event ($game_map.npcs are Game_Event)
  def self.count_active_undead_for(companion_event)
    return 0 unless companion_event && $game_map && $game_map.respond_to?(:npcs)
    count = 0
    $game_map.npcs.each do |ev|
      next if ev == companion_event
      next if ev.npc && (ev.npc.action_state == :death rescue false)
      next if ev.respond_to?(:deleted?) && ev.deleted? rescue next
      next unless ev.respond_to?(:actor) && ev.actor
      next unless ev.actor.respond_to?(:master) && ev.actor.master == companion_event
      count += 1
    end
    count
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
    
    # Only block movement for the one companion Player 2 is currently controlling; others use AI.
    begin
      if CoopConfig.manual_control? && CompanionControl.controlled_companion_event == self
        return
      end
    rescue => e
    end
    
    coop_original_update_self_movement
  end
  
  # Allow AI targeting when under manual control (sensor runs so companion can get @target for projectile skills)
  alias_method :coop_original_update_npc_sensor, :update_npc_sensor unless method_defined?(:coop_original_update_npc_sensor)
  
  def update_npc_sensor
    coop_original_update_npc_sensor
  end
end

#==============================================================================
# Game_NonPlayerCharacter Hook - Block AI skill choice when Player 2 controls the companion
#==============================================================================
# Target is still set by the AI (sensor); only the decision to launch a skill is blocked
# so that Player 2's key presses (skill1..skill6) are the only way to use skills.
#==============================================================================

class Game_NonPlayerCharacter
  alias_method :coop_original_process_killer, :process_killer unless method_defined?(:coop_original_process_killer)
  def process_killer(target, distance, signal, sensor_type)
    return if CoopConfig.manual_control? && CompanionControl.controlled_companion_event == self.map_token
    coop_original_process_killer(target, distance, signal, sensor_type)
  end

  alias_method :coop_original_process_assulter, :process_assulter unless method_defined?(:coop_original_process_assulter)
  def process_assulter(target, distance, signal, sensor_type)
    return if CoopConfig.manual_control? && CompanionControl.controlled_companion_event == self.map_token
    coop_original_process_assulter(target, distance, signal, sensor_type)
  end

  alias_method :coop_original_process_fucker, :process_fucker unless method_defined?(:coop_original_process_fucker)
  def process_fucker(target, distance, signal, sensor_type)
    return if CoopConfig.manual_control? && CompanionControl.controlled_companion_event == self.map_token
    coop_original_process_fucker(target, distance, signal, sensor_type)
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
