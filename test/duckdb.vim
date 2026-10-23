" Run from the repository root: nvim --headless -u NONE -i NONE -S test/duckdb.vim
set runtimepath^=.
runtime plugin/dadbod.vim
let s:directory = tempname()
call mkdir(s:directory, 'p')
let s:setup = s:directory . "/setup 'secrets' & config.sql"
call writefile(['SET VARIABLE dadbod_init_value = 42;',
      \ 'CREATE TEMP TABLE dadbod_init_table (id INTEGER);'], s:setup)
try
  let s:plain = db#resolve('duckdb:')
  call assert_equal(['42'], db#systemlist(
        \ db#adapter#duckdb#command(s:plain) + ['-list', '-noheader', 'SELECT 42;']))
  let s:variables = s:directory . '/variables.sql'
  call writefile(['SET VARIABLE dadbod_init_value = 42;'], s:variables)
  call assert_equal([], db#adapter#duckdb#tables(
        \ db#resolve('duckdb:?init=' . db#url#encode(s:variables))))
  for s:database in ['', s:directory . '/explicit.duckdb']
    let s:url = db#resolve('duckdb:' . s:database . '?init=' . db#url#encode(s:setup))
    let s:output = db#systemlist(db#adapter#duckdb#interactive(s:url),
          \ "SELECT getvariable('dadbod_init_value');\n")
    call assert_match('\<42\>', join(s:output, "\n"))
    call assert_match('dadbod_init_table', join(db#adapter#duckdb#tables(s:url)))
  endfor
  for s:parameter in ['init', 'init=', 'init=/missing/dadbod-setup.sql',
        \ 'init=' . db#url#encode(s:directory),
        \ 'init=' . db#url#encode(s:setup) . '&init=' . db#url#encode(s:setup)]
    try
      call db#adapter#duckdb#command(db#resolve('duckdb:?' . s:parameter))
      call assert_report('Expected invalid init path to be rejected: ' . s:parameter)
    catch /^DB: DuckDB init must name one readable file$/
    endtry
  endfor
catch
  call assert_report(v:exception . ' at ' . v:throwpoint)
finally
  call delete(s:directory, 'rf')
  if exists('s:plain')
    call delete(db#adapter#duckdb#dbext(s:plain).dbname)
  endif
endtry
if !empty(v:errors)
  echo join(v:errors, "\n")
  cquit
endif
qa!
