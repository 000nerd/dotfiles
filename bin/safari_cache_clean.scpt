-- Can be executed from Terminal using "osascript safari_cache_clean.scpt"
-- inspired by http://www.macuser.de/forum/f30/safari-alle-cache-544226/

set appname to "Safari"

if appIsRunning(appname) then
	set started to true
	-- Quit App
	tell application appname to quit
else
	set started to false
end if

-- Remove files
do shell script "rm -f ~/Library/Safari/history.plist"
do shell script "rm -f ~/Library/Safari/HistoryIndex.sk"
do shell script "rm -rf ~/Library/Safari/LocalStorage"
do shell script "rm -rf ~/Library/Safari/Databases"
do shell script "rm -f ~/Library/Caches/com.apple.Safari/Cache.db"
do shell script "rm -rf ~/Library/Caches/com.apple.Safari/Webpage\\ Previews"
do shell script "rm -rf ~/Library/Caches/Metadata/Safari/History"

-- Restart App if it was running before
if started then
	tell application appname to activate
end if

-- See http://techblog.willshouse.com/2012/02/21/applescript-check-application-is-running/
on appIsRunning(appname)
	tell application "System Events" to (name of processes) contains appname
end appIsRunning
