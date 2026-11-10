
####### Expanded from @PACKAGE_INIT@ by configure_package_config_file() #######
####### Any changes to this file will be overwritten by the next CMake run ####
####### The input file was MarbleConfig.cmake.in                            ########

get_filename_component(PACKAGE_PREFIX_DIR "${CMAKE_CURRENT_LIST_DIR}/../../../" ABSOLUTE)

macro(set_and_check _var _file)
  set(${_var} "${_file}")
  if(NOT EXISTS "${_file}")
    message(FATAL_ERROR "File or directory ${_file} referenced by variable ${_var} does not exist !")
  endif()
endmacro()

macro(check_required_components _NAME)
  foreach(comp ${${_NAME}_FIND_COMPONENTS})
    if(NOT ${_NAME}_${comp}_FOUND)
      if(${_NAME}_FIND_REQUIRED_${comp})
        set(${_NAME}_FOUND FALSE)
      endif()
    endif()
  endforeach()
endmacro()

####################################################################################

set(MARBLE_NO_WEBKITWIDGETS TRUE)

include(CMakeFindDependencyMacro OPTIONAL RESULT_VARIABLE _CMakeFindDependencyMacro_FOUND)

if (_CMakeFindDependencyMacro_FOUND)
    find_dependency(Qt6Core5Compat )
    find_dependency(Qt6Xml )
    find_dependency(Qt6Widgets )
    if (NOT MARBLE_NO_WEBKITWIDGETS)
        find_dependency(Qt6WebEngineWidgets )
    endif()
else()
    find_package(Qt6Core5Compat REQUIRED)
    find_package(Qt6Xml REQUIRED)
    find_package(Qt6Widgets REQUIRED)
    if (NOT MARBLE_NO_WEBKITWIDGETS)
        find_package(Qt6WebEngineWidgets REQUIRED)
    endif()
endif()

include("${CMAKE_CURRENT_LIST_DIR}/MarbleTargets.cmake")
