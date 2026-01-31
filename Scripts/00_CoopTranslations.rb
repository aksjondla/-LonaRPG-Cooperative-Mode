#==============================================================================
# Cooperative Mode - Translation System
#==============================================================================

module CoopTranslations
  
  TRANSLATIONS = {
    # Control toggle messages
    ready_player2: {
      english: "Ready player 2",
      caap: "Listo jugador 2",
      russian: "Игрок 2 готов"
    },
    player2_off: {
      english: "Player 2 off",
      caap: "Jugador 2 desactivado",
      russian: "Игрок 2 выключен"
    },
    
    # Force enable messages
    coop_enabled: {
      english: "Co-op enabled",
      caap: "Cooperativo activado",
      russian: "Кооператив включён"
    },
    no_companion: {
      english: "No companion found",
      caap: "No hay compañero",
      russian: "Компаньон не найден"
    },
    already_enabled: {
      english: "Already enabled",
      caap: "Ya está activado",
      russian: "Уже включено"
    },
    
    # Skill messages
    projectile_blocked: {
      english: "Unavailable (projectile)",
      caap: "No disponible (proyectil)",
      russian: "Недоступно (снаряд)"
    },
    
    # Debug/status messages
    companion_name: {
      english: "Companion",
      caap: "Compañero",
      russian: "Компаньон"
    },
    position: {
      english: "Position",
      caap: "Posición",
      russian: "Позиция"
    },
    skills: {
      english: "Skills",
      caap: "Habilidades",
      russian: "Навыки"
    }
  }
  
  # Get current game language
  def self.current_language
    return :english unless defined?($lang)
    
    case $lang.to_s.upcase
    when "CAAP"
      :caap
    when "RUS"
      :russian
    when "ENG"
      :english
    else
      :english  # Default to English for not supported languages
    end
  end
  
  # Get translated text for a key
  def self.get(key)
    lang = current_language
    translation = TRANSLATIONS[key]
    
    if translation
      translation[lang] || translation[:english]
    else
      key.to_s  # Fallback to key name if translation missing
    end
  end
  
  # Shorthand method
  def self.t(key)
    get(key)
  end
  
end
