include(CMakeFindDependencyMacro)

if (FALSE)
  find_dependency(Threads)
endif ()

include("${CMAKE_CURRENT_LIST_DIR}/log4cplusTargets.cmake")

# Static and Unicode library file names can be decorated. Keep their imported
# target names for compatibility while also providing the canonical target
# used by source-tree consumers and shared installations.
if (TRUE
    AND NOT TARGET log4cplus::log4cplus)
  add_library(log4cplus::log4cplus INTERFACE IMPORTED)
  set_property(TARGET log4cplus::log4cplus PROPERTY
    INTERFACE_LINK_LIBRARIES log4cplus::log4cplusU)
endif ()
