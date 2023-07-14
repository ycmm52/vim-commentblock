" if exists('g:commentblock_loaded')
"     finish
" endif
let g:commentblock_loaded = 1

augroup CommentBlock
    autocmd!
    nnoremap <silent> gac  :set operatorfunc=<SID>CommentBlock<cr>g@
    nnoremap <silent> gdc  :<c-u>call <SID>DeleteCommentBlock('.')<cr>
    nnoremap <silent> grac :<c-u>call <SID>ReaddCommentBlock('.')<cr>
    nnoremap <silent> gacc :<c-u>call <SID>CommentBlock('.')<cr>
    vnoremap <silent> gac  :<c-u>call <SID>CommentBlock(visualmode())<cr>
augroup END

let g:commentblock_commentString  = get(g:, 'commentblock_commentString', "#")
let g:commentblock_commentSpace   = get(g:, 'commentblock_commentSpace', ' ')
let g:commentblock_commentPrefix  = get(g:, 'commentblock_commentPrefix', repeat(g:commentblock_commentString, 3) . repeat(g:commentblock_commentSpace, 3) )
let g:commentblock_commentPostfix = get(g:, 'commentblock_commentPostfix' ,repeat(g:commentblock_commentSpace, 3) . repeat(g:commentblock_commentString, 3) )

function! s:CommentBlockInit()
    if &ft ==# 'vim'
        let g:commentblock_linePrefix = '" '
    elseif &ft ==# 'java'
        let g:commentblock_linePrefix = '// '
    else
        let g:commentblock_linePrefix = get(g:, 'commentblock_linePrefix', '')
    endif
endfunction

function! s:ReaddCommentBlock(type) abort
    call s:CommentBlockInit()
    call s:DeleteCommentBlock('.')
    if s:commentLineRange !=# [ 0 ]
        let s:newLineRange = [s:commentLineRange[0], s:commentLineRange[-1]-2]
        call s:AddCommentBlock(s:newLineRange)
    endif
endfunction

function! s:DeleteCommentBlock(type) abort
    call s:CommentBlockInit()
    let s:currentLineNr    = line('.')
    let s:commentLineRange = s:GetCommentLineNrs(s:currentLineNr)
    " echo s:commentLineRange
    if s:commentLineRange !=# [ 0 ]
        call s:DeleteComment(s:commentLineRange)
    endif
endfunction

function! s:DeleteComment(range)
    if a:range[-1] - a:range[0] == 2
        let isOneLine = 1
    else
        let isOneLine = 0
    endif

    for i in range(a:range[0]+1, a:range[-1]-1)
        let line = getline(i)
        let leadingSpace = matchstr(line, '^\s*')
        if isOneLine
            let mainPattern = matchstr(line, '^\s*' . g:commentblock_linePrefix . g:commentblock_commentPrefix . '\zs.\{-}\ze' . g:commentblock_commentPostfix)
            if mainPattern == "" && g:commentblock_commentSpace == " "
                let mainPattern = matchstr(line, '^\s*' . g:commentblock_linePrefix . repeat(g:commentblock_commentString, 3). g:commentblock_commentSpace . '\{0,3}' . '\zs.\{-}\ze' . g:commentblock_commentSpace . '\{0,3}' . repeat(g:commentblock_commentString, 3))
            endif
            let recoverPattern = leadingSpace . mainPattern
        else
            let mainPattern = matchstr(line, '^\s*' . g:commentblock_linePrefix . g:commentblock_commentPrefix . '\zs' . ' ' . '*' . '.\{-}\ze' . g:commentblock_commentSpace . '*' . g:commentblock_commentPostfix)
            if mainPattern == "" && g:commentblock_commentSpace == " "
                let mainPattern = matchstr(line, '^\s*' . g:commentblock_linePrefix . repeat(g:commentblock_commentString, 3). g:commentblock_commentSpace . '\{0,3}' . '\zs' . ' ' . '*' . '.\{-}\ze' . g:commentblock_commentSpace . '*' . g:commentblock_commentSpace . '\{0,3}' . repeat(g:commentblock_commentString, 3))
            endif
            let recoverPattern = leadingSpace . mainPattern
        endif
        call setline(i, recoverPattern)
    endfor

    silent! exec a:range[0] . "delete _"
    silent! exec a:range[-1]-1 . "delete _"
    call cursor(a:range[0], strlen(leadingSpace)+1)
endfunction

function! s:GetCommentLineNrs(currentLineNr) abort
    let lookUpFlag       = 1
    let lookDownFlag     = 1
    let upperLineNr      = a:currentLineNr
    let lowerLineNr      = a:currentLineNr
    let currentLine      = getline(a:currentLineNr)
    let s:leadingSpace   = matchstr(currentLine, '^\s*')
    let isDummyLine      = s:CheckIsDummyLine(currentLine)
    let isFirstLineValid = s:CheckIsCommentBlock(currentLine)

    if !isFirstLineValid
        return [ 0 ]
    else
        " ### Find comment block upper bound
        while lookUpFlag
            let lineNr      = upperLineNr - 1
            let line        = getline(lineNr)
            let isLineValid = s:CheckIsSameCommentBlock(line, s:leadingSpace)
            if isLineValid
                let upperLineNr = lineNr
            else
                let lookUpFlag = 0
            endif
        endwhile
        " ### Find comment block lower bound
        while lookDownFlag
            let lineNr      = lowerLineNr + 1
            let line        = getline(lineNr)
            let isLineValid = s:CheckIsSameCommentBlock(line, s:leadingSpace)
            if isLineValid
                let lowerLineNr = lineNr
            else
                let lookDownFlag = 0
            endif
        endwhile
    endif

    if a:currentLineNr ==# upperLineNr && isDummyLine
        return [upperLineNr, lowerLineNr +1]
    elseif a:currentLineNr ==# lowerLineNr && isDummyLine
        return [upperLineNr -1, lowerLineNr]
    else
        return [upperLineNr-1, lowerLineNr+1]
    endif
endfunction

function! s:CheckIsDummyLine(line)
    let isDummyLine = matchstr(a:line, '^\s*'.g:commentblock_linePrefix.g:commentblock_commentString.'*$')
    if isDummyLine ==# ""
        return 0
    else
        return 1
    endif
endfunction

function! s:CheckIsSameCommentBlock(line, leadingSpace)
    let isCommentBlock = s:CheckIsCommentBlock(a:line)
    let isDummyLine = s:CheckIsDummyLine(a:line)
    let lSpace = matchstr(a:line, '^\s*')
    if isCommentBlock && lSpace ==# a:leadingSpace && !isDummyLine
        return 1
    else
        return 0
    endif
endfunction

function! s:CheckIsCommentBlock(line)
    let isCommentBlock = matchstr(a:line, '^\s*'.g:commentblock_linePrefix.g:commentblock_commentString) . matchstr(a:line, '^\s*'.g:commentblock_linePrefix.g:commentblock_commentPrefix)
    if isCommentBlock ==# ""
        return 0
    else
        return 1
    endif
endfunction

function! s:CommentBlock(type) abort
    call s:CommentBlockInit()
    let currentLineNr = line('.')
    if a:type ==# 'V'
        let startLineNr = get(getpos("'<"), 1)
        let endLineNr   = get(getpos("'>"), 1)
        call s:AddCommentBlock([startLineNr, endLineNr])
    elseif a:type ==# 'line'
        let startLineNr = get(getpos("'["), 1)
        let endLineNr   = get(getpos("']"), 1)
        call s:AddCommentBlock([startLineNr, endLineNr])
    elseif a:type ==# '.'
        call s:AddCommentBlock([currentLineNr, currentLineNr])
    else
        return
    endif
endfunction

function! s:AddCommentBlock(lineNrList)
    let startLineNr    = a:lineNrList[0]
    let endLineNr      = a:lineNrList[-1]
    let s:startSpaceNr = 9999
    let maxLineNr      = 0

    for i in range(startLineNr, endLineNr)
        let line           = getline(i)
        " ### Calculate max leading white space number among lines
        let leadingEmpty = s:CalcLeadingSpace(line)
        if leadingEmpty < s:startSpaceNr
            let s:startSpaceNr = leadingEmpty
        endif
        " ### Calculate max line characters among lines
        let totalChars = s:CalcLineChars(line)
        if totalChars > maxLineNr
            let maxLineNr = totalChars
        endif
    endfor

    for i in range(startLineNr, endLineNr)
        " ### Get information
        let line                = getline(i)
        let originalLine        = line
        let leadingEmpty        = s:CalcLeadingSpace(line)
        let totalChars          = s:CalcLineChars(line)
        let addedLeadingSpaceNr = leadingEmpty - s:startSpaceNr
        let addedTailingSpaceNr = maxLineNr - totalChars

        " ### Modify main body
        let startSpace = matchstr(line, '^\s*')
        let lineStart  = strlen(startSpace)
        let line       = repeat(' ', s:startSpaceNr) . g:commentblock_linePrefix . g:commentblock_commentPrefix . repeat(g:commentblock_commentSpace, addedLeadingSpaceNr) . strpart(line, lineStart) . repeat(g:commentblock_commentSpace, addedTailingSpaceNr) . g:commentblock_commentPostfix
        call setline(i, line)
    endfor

    " ### Add dummy pattern
    let dummyPatternNr = strlen(g:commentblock_commentPrefix . repeat(g:commentblock_commentSpace, addedLeadingSpaceNr) . strpart(originalLine, lineStart) . repeat(g:commentblock_commentSpace, addedTailingSpaceNr) . g:commentblock_commentPostfix)
    let dummyPattern   = repeat(" ", s:startSpaceNr) . g:commentblock_linePrefix . repeat( g:commentblock_commentString ,dummyPatternNr)
    call append(endLineNr, dummyPattern)
    call append(startLineNr-1, dummyPattern)
endfunction

function! s:CalcLineChars(line)
    let leadingTab     = matchstr(a:line, '^\t*')
    let leadingTabNr   = strlen(leadingTab) * shiftwidth()
    let totalChars = strlen(a:line)
    if leadingTabNr != 0
        let totalChars = totalChars + strlen(leadingTab) * (shiftwidth() - 1)
    endif
    return totalChars
endfunction

function! s:CalcLeadingSpace(line)
    let leadingSpace   = matchstr(a:line, '^\ *')
    let leadingSpaceNr = strlen(leadingSpace)
    let leadingTab     = matchstr(a:line, '^\t*')
    let leadingTabNr   = strlen(leadingTab) * shiftwidth()
    let leadingEmpty   = max( [leadingSpaceNr, leadingTabNr] )
    return leadingEmpty
endfunction
