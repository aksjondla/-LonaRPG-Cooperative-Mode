COOP_MOD_ROOT = File.dirname(File.expand_path(__FILE__))

prp "==============================================="
prp "Loading Cooperative Mode mod..."
prp "==============================================="

begin
  require 'json'
rescue LoadError
  prp "  WARNING: JSON library not available"
  prp "  Keybindings will use defaults"
end

begin
  prp "  [LOADING] CoopTranslations..."
  load_script(File.join(COOP_MOD_ROOT, "Scripts/00_CoopTranslations.rb"))
  prp "  [OK] CoopTranslations loaded"
rescue => e
  prp "  [ERROR] CoopTranslations failed!"
  prp "  Error: #{e.message}"
  prp "  Line: #{e.backtrace[0]}"
end

begin
  prp "  [LOADING] CoopConfig..."
  load_script(File.join(COOP_MOD_ROOT, "Scripts/01_CoopConfig.rb"))
  prp "  [OK] CoopConfig loaded"
rescue => e
  prp "  [ERROR] CoopConfig failed!"
  prp "  Error: #{e.message}"
  prp "  Line: #{e.backtrace[0]}"
end

begin
  prp "  [LOADING] CoopInput..."
  load_script(File.join(COOP_MOD_ROOT, "Scripts/02_CoopInput.rb"))
  prp "  [OK] CoopInput loaded"
rescue => e
  prp "  [ERROR] CoopInput failed!"
  prp "  Error: #{e.message}"
  prp "  Line: #{e.backtrace[0]}"
end

begin
  prp "  [LOADING] CompanionControl..."
  load_script(File.join(COOP_MOD_ROOT, "Scripts/03_CompanionControl.rb"))
  prp "  [OK] CompanionControl loaded"
rescue => e
  prp "  [ERROR] CompanionControl failed!"
  prp "  Error: #{e.message}"
  prp "  Line: #{e.backtrace[0]}"
end

begin
  prp "  [LOADING] SummonEventFix..."
  load_script(File.join(COOP_MOD_ROOT, "Scripts/04_SummonEventFix.rb"))
  prp "  [OK] SummonEventFix loaded"
rescue => e
  prp "  [ERROR] SummonEventFix failed!"
  prp "  Error: #{e.message}"
  prp "  Line: #{e.backtrace[0]}"
end

prp "==============================================="
prp "Cooperative Mode loading completed!"
prp "Type 'coop_status' in console for info."
prp "==============================================="
