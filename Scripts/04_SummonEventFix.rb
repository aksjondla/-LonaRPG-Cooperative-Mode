# encoding: utf-8

class Game_Map
  def ask_summon_event(event_name, x = nil, y = nil, id = -1, data = nil)
    x = $game_player.x if x.nil?
    y = $game_player.y if y.nil?
    if event_lib[event_name].nil?
      msgbox "Summon event, event not found.\n#{event_name},x=#{x},y=#{y}"
      return
    end
    summoned_ev = Marshal.load(Marshal.dump(event_lib[event_name][1]))
    summ_event_id = @events.keys.max
    summ_event_id = summ_event_id.nil? ? 1 : summ_event_id + 1
    @added_ev_ids.push(summ_event_id)
    summoned_ev.x = x
    summoned_ev.y = y
    summoned_ev.id = summ_event_id
    appended_event = Game_Event.new(@map_id, summoned_ev, data)
    appended_event.summoner_id = id
    @events[summ_event_id] = appended_event
    appended_event.foreign_event = true
    appended_event
  end
end
