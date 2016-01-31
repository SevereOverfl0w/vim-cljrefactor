" cljrefactor.vim - Clojure Refactoring Support
" Maintainer:  Frazer Irving ()
" Version:      0.1
" GetLatestVimScripts: 9999 1 :AutoInstall: cljrefactor.vim


if exists("g:loaded_refactor") || v:version < 700 || &cp
  finish
endif

let g:loaded_refactor = 1

function <SID>FindUsages()
    lgetex []
    let word = expand('<cword>')
    let symbol = fireplace#info(word)
    let usages = fireplace#message({"op": "find-symbol", "ns": symbol.ns, "name": symbol.name, "dir": ".", "line": symbol.line, "serialization-format": "bencode"})
    for usage in usages
        if !has_key(usage, 'occurrence')
            "echo "Not long enough: "
            "echo usage
            continue
        else
            let occ = usage.occurrence
            let i = 0
            let mymap = {}
            for kv in occ
                if i % 2
                    let mymap[occ[i - 1]] = occ[i]
                endif
                let i = i + 1
            endfor
            let msg = printf('%s:%d:%s', mymap['file'], mymap['line-beg'], mymap['col-beg'])
            laddex msg
        endif
    endfor
endfunction

function cljrefactor#ArtifactList()
    let artifacts = fireplace#message({"op": "artifact-list"})
    echo artifacts
endfunction

function cljrefactor#GetCleanNs()
    let filename = expand("%:p")
    let cleaned_res = fireplace#message({"op": "clean-ns", "path": filename})[0]
    let cleaned = cleaned_res.ns
    if type(cleaned) == type([])
      return ''
    else
      return cleaned
    endif
endfunction

function! s:opfunc(type) abort
  let sel_save = &selection
  let cb_save = &clipboard
  let reg_save = @@
  try
    set selection=inclusive clipboard-=unnamed clipboard-=unnamedplus
    echo type(0)
    echo type(a:type)
    if type(a:type) == type(0)
      let open = '[[{(]'
      let close = '[]})]'
      if getline('.')[col('.')-1] =~# close
        let [line1, col1] = searchpairpos(open, '', close, 'bn', g:fireplace#skip)
        let [line2, col2] = [line('.'), col('.')]
      else
        let [line1, col1] = searchpairpos(open, '', close, 'bcn', g:fireplace#skip)
        let [line2, col2] = searchpairpos(open, '', close, 'n', g:fireplace#skip)
      endif
      while col1 > 1 && getline(line1)[col1-2] =~# '[#''`~@]'
        let col1 -= 1
      endwhile
      call setpos("'[", [0, line1, col1, 0])
      call setpos("']", [0, line2, col2, 0])
      silent exe "normal! `[v`]y"
    elseif a:type =~# '^.$'
      silent exe "normal! `<" . a:type . "`>y"
    elseif a:type ==# 'line'
      silent exe "normal! '[V']y"
    elseif a:type ==# 'block'
      silent exe "normal! `[\<C-V>`]y"
    elseif a:type ==# 'outer'
      call searchpair('(','',')', 'Wbcr', g:fireplace#skip)
      silent exe "normal! vaby"
    else
      silent exe "normal! `[v`]y"
    endif
    redraw
    if fireplace#client().user_ns() ==# 'user'
      return repeat("\n", line("'<")-1) . repeat(" ", col("'<")-1) . @@
    else
      return @@
    endif
  finally
    let @@ = reg_save
    let &selection = sel_save
    let &clipboard = cb_save
  endtry
endfunction

function! cljrefactor#cleanns() abort
  let l:winview = winsaveview()
  normal! gg
  call s:opfunc(v:count)
  let @@ = cljrefactor#GetCleanNs()
  if @@ !~# '^\n*$'
    normal! gvp
    normal! gv=
    " I have no idea why I need to delete a line. Empty one is created though
    normal! kdd 
  endif
  call winrestview(l:winview)
endfunction

nmap <silent> cns :call cljrefactor#cleanns()<CR>
