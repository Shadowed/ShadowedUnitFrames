# Train against the WoW UI first
path = File.expand_path("../../../../BlizzardInterfaceCode/Interface", __FILE__)

$ranked = {}
Dir["#{path}/{AddOns,FrameXML}/**/*.lua"].each do |file|
	res = `luac -l '#{file}' 2>&1`
	if res !~ /^luac/
		res.split("\n\t").each do |line|
			_, line, type, offset, target = line.split("\t")
			next unless target

			if type == "GETGLOBAL"
				target.gsub!(";", "")
				target.strip!

				$ranked[target] ||= 0
				$ranked[target] += 1
			end
		end
	end
end

# Anything that we don't use enough or WoW doesn't use enough for it to be trained
$blacklisted = ["ShadowUF", "rawset", "rawget", "setfenv", "getfenv", "math", "GetLocale", "UnitReaction", "LibStub", "loadstring", "print", "IsResting", "UnitAura", "UnitIsFriend", "GetComboPoints", "GetEclipseDirection", "UnitIsTapped", "UnitPlayerControlled", "UnitCreatureFamily", "UnitThreatSituation", "UnitClassification", "UnitInPhase", "IsEveryoneAssistant", "UnitStagger", "RegisterUnitWatch", "UnregisterUnitWatch", "UnitIsVisible", "UnitInRange", "CheckInteractDistance", "GetRuneCooldown", "GetRuneType", "GetTotemInfo", "RegisterStateDriver", "ClickCastHeader", "ClickCastFrames", "IsPlayerSpell", "UnitXP", "GetPetExperience", "GetBuildInfo", "CompactPartyFrame", "hooksecurefunc", "TemporaryEnchantFrame", "PriestBarFrame", "PaladinPowerBar", "EclipseBarFrame", "ShardBarFrame", "RuneFrame", "MonkHarmonyBar", "ComboFrame", "QueueStatusFrame", "LoadAddOn", "UnitIsEnemy", "IsUsableSpell"]

# Filter check
def filtered?(target)
	if $ranked[target] and $ranked[target] >= 6
		true
	elsif $blacklisted.include?(target)
		true
	elsif target.gsub(/[^A-Z]/, "").length >= 4
		true
	else
		false
	end
end

# Check all files for leaked globals
total = 0
Dir["./**/*.lua"].each do |file|
	next if file =~ /localcheck/

	res = `luac -l #{file} 2>&1`
	if res =~ /luac:/
		puts "#{res.gsub("luac:", "").strip}"
		next
	end

	leaked = []
	res.split("\n\t").each do |line|
		_, line, type, offset, target = line.split("\t")
		next unless target
		next unless type == "SETGLOBAL" or type == "GETGLOBAL"

		target.gsub!(";", "")
		target.strip!
		next if filtered?(target)

		leaked << {line: line, target: target}
	end

	next if leaked.empty?
	total += 1

	puts
	puts file
	leaked.each do |row|
		puts "#{row[:line]} #{row[:target]}"
	end
end

if total == 0
	puts "No leaked globals found!"
end

File.unlink("./luac.out") rescue nil
