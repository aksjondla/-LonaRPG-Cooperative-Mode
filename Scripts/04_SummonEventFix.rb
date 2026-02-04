# encoding: utf-8
# -----------------------------------------------------------------------------
# Cooperative mode — Summon event fix (solo archivos del mod, no toca el juego)
# El juego reutiliza el mismo RPG::Event de la librería para cada invocación,
# mutando x/y/id y corrompiendo invocaciones anteriores (ej. 6º esqueleto crashea).
# Este script parchea Game_Map#ask_summon_event para usar una copia por invocación.
# -----------------------------------------------------------------------------

class Game_Map
  def ask_summon_event(event_name, x = nil, y = nil, id = -1, data = nil)
    x = $game_player.x if x.nil?
    y = $game_player.y if y.nil?
    if event_lib[event_name].nil?
      msgbox "Summon event, event not found.\n#{event_name},x=#{x},y=#{y}"
      return
    end
    # Copia del evento de la librería para esta invocación (evita crash al invocar varios del mismo tipo)
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
