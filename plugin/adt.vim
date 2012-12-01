"The main entrance 
function! AdtLogcat()
	exec "cclose"
	let l:packageName = GetPackageName('./')
	let l:packageName = substitute(l:packageName, "\\.", "\\\\.", "g")
	if strlen(l:packageName) == 0
		echo "Failed to fetch the package name"
		return 1
	endif
	echo "Fetching logs..."
	exec "sp /dev/null/l.txt | r!adb shell logcat -d"
	let l:regexp = "\\vActivityManager.*Start\\s*proc\\s*".l:packageName
	let l:searchRet = searchpos(l:regexp, "b")
	let l:lineNumber = l:searchRet[0]
	let l:line = getline(l:lineNumber)
	let l:pid = matchstr(l:line, "\\v\\s*pid\\s*\\=\\d+")
	let l:pid = matchstr(l:pid, "\\v\\d+")
	if strlen(l:pid) > 0
		let l:cmd = "v/".pid."/d"
		exec l:cmd
	else
		exec "q!"
		echo "Failed to fetch pid for ".l:packageName
	endif
endf

function! AdtBuild()
	set efm=%E\ \ \ \ [javac]%f:%l:\ %m
	exec "cclose"
	echo "Building..."
	let l:buildStr = system("ant debug")
	let l:installSuccessReg = "\\vBUILD\\s+SUCCESSFUL.*Total\\s+time\\:\\s+\\d+\\s+seconds"
	let l:installStrRet = matchstr(l:buildStr, l:installSuccessReg)
	if empty(l:installStrRet)
		call writefile(split(l:buildStr, "\n"), "/tmp/l.txt")
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

function! AdtRun()
	exec "cclose"
	echo "Installing..."
	let l:installStr = system("ant installd")
	let l:installSuccessReg = "\\vBUILD\\s+SUCCESSFUL.*Total\\s+time\\:\\s+\\d+\\s+seconds"
	let l:installStrRet = matchstr(l:installStr, l:installSuccessReg)
	if (empty(l:installStrRet))
		echo l:installStr
		return 1
	else
		echo "Success to install."
	endif
	
	let l:packageName = GetPackageName('./')
	let l:mainActivity = GetMainActivity('./')
	let l:cmd = "adb shell am start -n ".l:packageName."/".l:mainActivity
	echo "Starting activity..."
	let l:execRet = system(l:cmd)
	echo l:execRet
	return 0
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
				let l:ret = l:activityName
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


nmap La :call AdtLogcat()<cr>
nmap Ab :call AdtBuild()<cr>
nmap Ar :call AdtRun()<cr>
