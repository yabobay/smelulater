project('smelulater', 'd')
compiler = meson.get_compiler('d')

libedit = true

sources = ['smelulater.d', 'gmp_wrapper.d']
link_args = ['-lgmp']

if libedit
  sources += 'libedit.d'
  link_args += '-ledit'
endif

executable(
  'smelulater', sources,
  d_module_versions: libedit ? ['Libedit'] : [],
  include_directories : 'libgmp/source',
  link_args : link_args)
