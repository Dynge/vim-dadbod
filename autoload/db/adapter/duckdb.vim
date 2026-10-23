function! db#adapter#duckdb#canonicalize(url) abort
  return db#url#canonicalize_file(a:url)
endfunction

function! db#adapter#duckdb#test_file(file) abort
  if getfsize(a:file) < 100
    return
  endif
  let firstline = readfile(a:file, '', 1)[0]
  " DuckDB can also open SQLite databases
  if firstline[8:11] ==# 'DUCK' || firstline =~# '^SQLite format 3\n'
    return 1
  endif
endfunction

function! s:path(url) abort
  let path = db#url#file_path(a:url)
  if path =~# '^[\/]\=$'
    if !exists('s:session')
      let s:session = tempname() . '.duckdb'
    endif
    let path = s:session
  endif
  return path
endfunction

function! db#adapter#duckdb#dbext(url) abort
  return {'dbname': s:path(a:url)}
endfunction

function! db#adapter#duckdb#command(url) abort
  if assert_equal(type(''), type(a:url))
    throw 'DB: DuckDB URL must be a string'
  endif
  let command = ['duckdb', s:path(a:url)]
  let params = db#url#parse(a:url).params
  if has_key(params, 'init')
    let init = params.init
    if type(init) != type('') || empty(init) || init =~# "\f" || !filereadable(init)
      throw 'DB: DuckDB init must name one readable file'
    endif
    let command += ['-init', init]
  endif
  if assert_false(empty(command[1]))
    throw 'DB: DuckDB database path must not be empty'
  endif
  return command
endfunction

function! db#adapter#duckdb#interactive(url) abort
  return db#adapter#duckdb#command(a:url) + ['-column', '-header']
endfunction

function! db#adapter#duckdb#tables(url) abort
  let lines = db#systemlist(db#adapter#duckdb#command(a:url) + ['-noheader', '.tables'])
  call map(lines, 'substitute(v:val, ''\e\[[0-9;]*m'', "", "g")')
  call filter(lines, 'v:val !~# "^-- Loading resources from "')
  return split(join(lines))
endfunction

function! db#adapter#duckdb#massage(input) abort
  return a:input . "\n;"
endfunction
