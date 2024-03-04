include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(Vulkc_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(Vulkc_setup_options)
  option(Vulkc_ENABLE_HARDENING "Enable hardening" ON)
  option(Vulkc_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    Vulkc_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    Vulkc_ENABLE_HARDENING
    OFF)

  Vulkc_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR Vulkc_PACKAGING_MAINTAINER_MODE)
    option(Vulkc_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(Vulkc_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(Vulkc_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(Vulkc_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(Vulkc_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(Vulkc_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(Vulkc_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(Vulkc_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(Vulkc_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(Vulkc_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(Vulkc_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(Vulkc_ENABLE_PCH "Enable precompiled headers" OFF)
    option(Vulkc_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(Vulkc_ENABLE_IPO "Enable IPO/LTO" ON)
    option(Vulkc_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(Vulkc_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(Vulkc_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(Vulkc_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(Vulkc_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(Vulkc_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(Vulkc_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(Vulkc_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(Vulkc_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(Vulkc_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(Vulkc_ENABLE_PCH "Enable precompiled headers" OFF)
    option(Vulkc_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      Vulkc_ENABLE_IPO
      Vulkc_WARNINGS_AS_ERRORS
      Vulkc_ENABLE_USER_LINKER
      Vulkc_ENABLE_SANITIZER_ADDRESS
      Vulkc_ENABLE_SANITIZER_LEAK
      Vulkc_ENABLE_SANITIZER_UNDEFINED
      Vulkc_ENABLE_SANITIZER_THREAD
      Vulkc_ENABLE_SANITIZER_MEMORY
      Vulkc_ENABLE_UNITY_BUILD
      Vulkc_ENABLE_CLANG_TIDY
      Vulkc_ENABLE_CPPCHECK
      Vulkc_ENABLE_COVERAGE
      Vulkc_ENABLE_PCH
      Vulkc_ENABLE_CACHE)
  endif()

  Vulkc_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (Vulkc_ENABLE_SANITIZER_ADDRESS OR Vulkc_ENABLE_SANITIZER_THREAD OR Vulkc_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(Vulkc_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(Vulkc_global_options)
  if(Vulkc_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    Vulkc_enable_ipo()
  endif()

  Vulkc_supports_sanitizers()

  if(Vulkc_ENABLE_HARDENING AND Vulkc_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR Vulkc_ENABLE_SANITIZER_UNDEFINED
       OR Vulkc_ENABLE_SANITIZER_ADDRESS
       OR Vulkc_ENABLE_SANITIZER_THREAD
       OR Vulkc_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${Vulkc_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${Vulkc_ENABLE_SANITIZER_UNDEFINED}")
    Vulkc_enable_hardening(Vulkc_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(Vulkc_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(Vulkc_warnings INTERFACE)
  add_library(Vulkc_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  Vulkc_set_project_warnings(
    Vulkc_warnings
    ${Vulkc_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(Vulkc_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(Vulkc_options)
  endif()

  include(cmake/Sanitizers.cmake)
  Vulkc_enable_sanitizers(
    Vulkc_options
    ${Vulkc_ENABLE_SANITIZER_ADDRESS}
    ${Vulkc_ENABLE_SANITIZER_LEAK}
    ${Vulkc_ENABLE_SANITIZER_UNDEFINED}
    ${Vulkc_ENABLE_SANITIZER_THREAD}
    ${Vulkc_ENABLE_SANITIZER_MEMORY})

  set_target_properties(Vulkc_options PROPERTIES UNITY_BUILD ${Vulkc_ENABLE_UNITY_BUILD})

  if(Vulkc_ENABLE_PCH)
    target_precompile_headers(
      Vulkc_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(Vulkc_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    Vulkc_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(Vulkc_ENABLE_CLANG_TIDY)
    Vulkc_enable_clang_tidy(Vulkc_options ${Vulkc_WARNINGS_AS_ERRORS})
  endif()

  if(Vulkc_ENABLE_CPPCHECK)
    Vulkc_enable_cppcheck(${Vulkc_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(Vulkc_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    Vulkc_enable_coverage(Vulkc_options)
  endif()

  if(Vulkc_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(Vulkc_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(Vulkc_ENABLE_HARDENING AND NOT Vulkc_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR Vulkc_ENABLE_SANITIZER_UNDEFINED
       OR Vulkc_ENABLE_SANITIZER_ADDRESS
       OR Vulkc_ENABLE_SANITIZER_THREAD
       OR Vulkc_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    Vulkc_enable_hardening(Vulkc_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
