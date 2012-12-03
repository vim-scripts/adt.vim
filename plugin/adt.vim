"Author Chen Chi, call me Cook in English, and contact with me by
"reallychenchi@163.com or reallychenchi@gmail.com
"
"Functions:
"	AdtLogcat	Fetch logs from android device and display in copen
"			window. If there are error or warning stacks, it will
"			be recorgnized as error, so that you can switch between
"			error message and codes by :cn and :cp. By default, it
"			is mapped as "Al"
"
"	AdtBuild`	Build the current android application, make sure there
"			are build.xml and AndroidMenifest.xml in current folder. 
"			The build log will be displayed in copen window, so
"			that you can switch between error message and codes by
"			:cn and :cp. By default, it is mapped as "Ab"
"
"	AdtRun		Run the current android application, make sure there
"			are build.xml and AndroidMenifest.xml in current
"			folder. By default, it is mapped as "Ar"
"
"	AdtClean	Clean the current android application build
"			envirovement. By default, it is mapped as "Ac"
"
"	AdtHelp		Get the help information of the word under cursor,
"			the cooresponding html file in android docs folder
"			will be opened by xdg-open. By default, it is mapped
"			as "Ah"

function! AdtLogcat()
	exec "cclose"
	let l:devices = GetDevices()
	if len(l:devices) == 0
		echo "Failed to get log for no aviable Android device, please check by command \"adb devices\""
		return 1
	endif

	let l:packageName = GetPackageName('./')
	let l:packageName = substitute(l:packageName, "\\.", "\\\\.", "g")
	if strlen(l:packageName) == 0
		echo "Failed to fetch the package name"
		return 1
	endif
	let l:logstr = system("adb shell logcat -d")
	let l:logLines = split(logstr, "\n")
	let l:regexp = "\\vActivityManager.*Start\\s*proc\\s*".l:packageName
	let l:pid = ""
	for line in l:logLines
		if match(line, l:regexp) > -1
			let l:pid = matchstr(line, "\\v\\s*pid\\s*\\=\\d+")
			let l:pid = matchstr(l:pid, "\\v\\d+")
		endif
	endfor
	let l:logAppLines = []
	if empty(l:pid)
		echo "Failed to fetch pid for ".l:packageName
	endif

	for line in l:logLines
		if match(line, "\\v[WDIE]\\/.{-}\\(".l:pid."\\)") > -1
			call add(l:logAppLines, line)
		endif
	endfor

	if len(l:logAppLines) == 0
		echo "No logs for ".l:packageName." found"
		return 1
	endif
	let l:sourceDir = GetSourceDir()
	let l:regPre = "\\v[WE]\\/System\\.err\\(".l:pid."\\)\\:\\s+at\\s*"
	let l:idx = 0
	for line in l:logAppLines
		let l:preLine = matchstr(line, l:regPre)
		if !empty(l:preLine)
			let l:infoLine = substitute(line, l:regPre, "", "")
			let l:packageInfo = matchstr(l:infoLine, "\\v\\S+(\\()\@=")
			let l:fileInfo = matchstr(l:infoLine, "\\v(\\()\@<=\\S+(\\:)\@=")
			let l:numInfo = matchstr(l:infoLine, "\\v(\\:)\@<=\\S+(\\))\@=")
			let l:fileName = GetFileName(l:sourceDir, l:packageInfo, l:fileInfo)
			if !empty(l:fileName)
				let line = "[E]".l:fileName.":".l:numInfo." ".l:preLine.l:packageInfo
				let l:logAppLines[l:idx] = line
			endif
		endif
		let l:idx = l:idx + 1
	endfor
	call writefile(l:logAppLines, "/tmp/l.txt")
	set efm=[E]%f:%l\ %m
	set makeprg=cat\ /tmp/l.txt
	exec "silent make"
	exec "copen"	
	return 0
endf

function! AdtRun()
	exec "cclose"
	let l:devices = GetDevices()
	if len(l:devices) == 0
		echo "Installation cancled for no aviable Android device, please check by command \"adb devices\""
		return 1
	endif

	echo "Installing..."
	let l:antRet = Ant("installd")
	if len(l:antRet) != 0
		call writefile(l:antRet, "/tmp/l.txt")
		set makeprg=cat\ /tmp/l.txt
		exec "silent make"
		exec "copen"	
		return 1
	else
		echo "Success to install."
		let l:packageName = GetPackageName('./')
		let l:mainActivity = GetMainActivity('./')
		let l:cmd = "adb shell am start -n ".l:packageName."/".l:mainActivity
		echo "Starting activity..."
		let l:execRet = system(l:cmd)
		echo l:execRet
		return 0
	endif
endf

function! AdtBuild()
	exec "cclose"
	echo "Building..."

	let l:antRet = Ant("debug")
	if len(l:antRet) != 0
		let idx = 0
		let l:regAaptErr = "\\v\\s{-}\\[aapt\\]\\s(\\/\\S{-}){-}\\/\\S{-}\\:\\d+\\:\\serror\\:"
		for line in l:antRet
			if match(line, l:regAaptErr) > -1
				let line = substitute(line,"\\v\\s{-}\\[aapt\\]\\s", "    [javac]", "") 
				let l:antRet[idx] = line
			endif
			let l:idx = l:idx + 1
		endfor
		call writefile(l:antRet, "/tmp/l.txt")
		set efm=%E\ \ \ \ [javac]%f:%l:\ %m
		set makeprg=cat\ /tmp/l.txt
		exec "silent make"
		exec "copen"	
		return 1
	else
		echo "Build successful."
		call AdtRun()
		return 0
	endif
endf

function! AdtClean()
	exec "cclose"
	echo "Clean..."

	let l:antRet = Ant("clean")
	if len(l:antRet) != 0
		echo "failed"
		call writefile(l:antRet, "/tmp/l.txt")
		set makeprg=cat\ /tmp/l.txt
		return 1
	else
		echo "Clean successful."
		return 0
	endif
endf

function! AdtHelp()
	let l:line = getline(line("."))
	let l:col = col(".")
	let l:lineH1 = strpart(l:line, 0, l:col)
	let l:lineH1 = matchstr(l:lineH1, "\\v<[a-zA-Z_][a-zA-Z0-9_$]*$")
	let l:lineH2 = strpart(l:line, l:col)
	let l:lineH2 = matchstr(l:lineH2, "\\v[a-zA-Z0-9_$]*")
	let l:word = l:lineH1.l:lineH2
	"let l:tags = taglist(l:word)
	let l:path = system("which android")
	if empty(l:path)
		echo "Android is not installed, documents not found package"
	else
		let l:path = matchstr(l:path, "\\v\\S+(\\/tools\\/android)\@=")
		let l:cmd = "find ".l:path." -name ".l:word.".html"
		let l:finds = system(l:cmd)
		let l:fileList = split(l:finds, "\n")
		if len(l:fileList) == 1
			call system("xdg-open ".l:fileList[0])
		elseif len(l:fileList) > 1
			let l:idx = inputlist(l:fileList)
			call system("xdg-open ".l:fileList[l:idx])
		else
			echo "Keyword ".l:word." is not found in android documents"
		endif
	endif
endf

function! Ant(para)
	let l:antRet = system("ant ".a:para)
	let l:antSuccessReg = "\\vBUILD\\s+SUCCESSFUL.*Total\\s+time\\:\\s+\\d+\\s+second"
	let l:antRunRet = matchstr(l:antRet, l:antSuccessReg)
	if empty(l:antRunRet)
		return split(l:antRet, "\n")
	else
		return []
	endif
endf

function! GetFileName(dirs, packageName, fn)
	let l:ret = ""

	let l:fileName = matchstr(a:fn, "\\v\\S+(\\.)\@=")
	let l:dirName = matchstr(a:packageName, "\\v\\S+(".l:fileName.")\@=")
	let l:fileName = substitute(l:dirName, "\\.", "/", "g").a:fn
	for dir in a:dirs
		let l:ret = dir.l:fileName
		let l:ret = findfile(l:ret, ".;")
		if !empty(l:ret)
			break
		endif
	endfor
	return l:ret
endf

function! GetSourceDir()
	let l:ret = ["./src/"]
	let l:fn = "project.properties"
	let l:regAndroidLibPrj = "\\v(android\\.library\\.reference\\.\\d+\\s*\\=)@<=\\S+($)\@="
	let l:lines = readfile(l:fn, '')
	for line in l:lines
		let l:libSource = matchstr(line, l:regAndroidLibPrj)
		if !empty(l:libSource)
			call add(l:ret, l:libSource."/src/")
		endif
	endfor

	return l:ret
endf

function! GetMainActivity(path)
	let l:ret = ""
	let l:fn = a:path . 'AndroidManifest.xml'
	let l:str = GetFileContent(l:fn)
	let l:nodes = GetNodes(l:str, 'manifest', 'application', 'activity')
	for node in l:nodes
		let l:activityName = GetProperty(node, 'android:name')
		let l:actions = GetNodes(node, 'intent-filter', 'action')
		for action in l:actions
			let l:actName = GetProperty(action, 'android:name')
			if l:actName == "android.intent.action.MAIN"
				if match(l:activityName, "\\.") == -1
					let l:ret = ".".l:activityName
				else
					let l:ret = l:activityName
				endif
				break
			endif
		endfor
		if !empty(l:ret)
			break
		endif
	endfor
	return l:ret
endf

"The get package name from path
function! GetPackageName(path)
	let l:ret = ""
	let l:fn = a:path . 'AndroidManifest.xml'
	let l:str = GetFileContent(l:fn)
	let l:nodes = GetNodes(l:str, 'manifest')
	for node in l:nodes
		let l:ret = GetProperty(node, 'package')
		if !empty(l:ret)
			break
		endif
	endfor

	return l:ret
endf

function! GetFileContent(fn)
	let l:lines = readfile(a:fn, '')
	let l:str = ''
	for line in lines
		let l:str = l:str . line
	endfor
	return l:str
endf

function! GetNodes(str, ...)
	let l:ret = []
	let l:num = a:0
	let l:lastNode = a:000[num - 1]
	let l:names = []
	let l:curNodes = [a:str]
	let l:curBNodes = [] 
	for index in range(len(a:000) - 1)
		call add(l:names, a:000[index])
	endfor

	for name in l:names
		for node in l:curNodes
			let l:nodes = GetMatchList(node, "\\v\\<".name.".{-}\\>.{-}\\<\\/".name."\\>")
			for nodeTiny in l:nodes
				call add(l:curBNodes, nodeTiny)
			endfor
		endfor
		let l:curNodes = l:curBNodes
		let l:curBNodes = []
	endfor

	let l:ret = []
	for node in curNodes
		let l:lastNodes = GetMatchList(node, "\\v(\\<".l:lastNode.".{-}\\>.{-}\\<\\/".l:lastNode."\\>)|".
					\"(\\<".l:lastNode.".{-}\\>.{-}\\/\\>)")
		for retNode in l:lastNodes
			call add(l:ret, retNode)
		endfor
	endfor
	
	return l:ret
endf

function! GetMatchList(str, pattern)
	let l:ret = []
	let l:pos = 0
	let l:len = strlen(a:str)
	
	while l:pos < l:len
		let l:str = matchstr(a:str, a:pattern, l:pos)
		if empty(l:str)
			break
		endif
		let l:pos = l:pos + strlen(l:str)
		call add(l:ret, l:str)
	endwhile
	return l:ret
endf

function! GetProperty(str, property)
	let l:pro = matchstr(a:str, "\\v".a:property."\\s*\\=\\s*\\\".{-}\"")
	let l:pro = matchstr(l:pro, "\\v\\\".*\"")
	let l:ret = l:pro[1:-2]
	return l:ret
endf

function! GetDevices()
	let l:ret = []
	let l:checkRets = system("adb devices")
	let l:checkRet = split(l:checkRets, "\n")
	let l:idx = -1 
	while l:idx < len(l:checkRet)
		let l:line = l:checkRet[l:idx]
		let l:idx = l:idx + 1
		if match(l:line, "List of devices attached") > -1
			break
		endif
	endwhile
	while l:idx < len(l:checkRet)
		let l:line = l:checkRet[l:idx]
		let l:idx = l:idx + 1
		if match(l:line, "\\v\\sdevice") > 0
			let l:deviceName = matchstr(l:line, "\\v\\S+")
			if match(l:deviceName, "\\v^\\?+$") == -1
				call add(l:ret, l:deviceName)
			endif
		endif
	endwhile

	return l:ret
endf

nmap Al :call AdtLogcat()<cr>
nmap Ab :call AdtBuild()<cr>
nmap Ac :call AdtClean()<cr>
nmap Ar :call AdtRun()<cr>
nmap Ah :call AdtHelp()<cr>
