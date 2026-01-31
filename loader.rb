prp "==============================================="
prp "Loading Cooperative Mode mod..."
prp "==============================================="

# Load JSON library if not already loaded
begin
  require 'json'
rescue LoadError
  prp "  WARNING: JSON library not available"
  prp "  Keybindings will use defaults"
end

# Test 0: Load CoopTranslations (must be first)
begin
  prp "  [LOADING] CoopTranslations..."
  load_script("ModScripts/_Mods/Cooperative mode/Scripts/00_CoopTranslations.rb")
  prp "  [OK] CoopTranslations loaded"
rescue => e
  prp "  [ERROR] CoopTranslations failed!"
  prp "  Error: #{e.message}"
  prp "  Line: #{e.backtrace[0]}"
end

# Test 1: Load CoopConfig
begin
  prp "  [LOADING] CoopConfig..."
  load_script("ModScripts/_Mods/Cooperative mode/Scripts/01_CoopConfig.rb")
  prp "  [OK] CoopConfig loaded"
rescue => e
  prp "  [ERROR] CoopConfig failed!"
  prp "  Error: #{e.message}"
  prp "  Line: #{e.backtrace[0]}"
end

# Test 2: Load CoopInput
begin
  prp "  [LOADING] CoopInput..."
  load_script("ModScripts/_Mods/Cooperative mode/Scripts/02_CoopInput.rb")
  prp "  [OK] CoopInput loaded"
rescue => e
  prp "  [ERROR] CoopInput failed!"
  prp "  Error: #{e.message}"
  prp "  Line: #{e.backtrace[0]}"
end

# Test 3: Load CompanionControl
begin
  prp "  [LOADING] CompanionControl..."
  load_script("ModScripts/_Mods/Cooperative mode/Scripts/03_CompanionControl.rb")
  prp "  [OK] CompanionControl loaded"
rescue => e
  prp "  [ERROR] CompanionControl failed!"
  prp "  Error: #{e.message}"
  prp "  Line: #{e.backtrace[0]}"
end

prp "==============================================="
prp "Cooperative Mode loading completed!"
prp "Type 'coop_status' in console for info."
prp "==============================================="
