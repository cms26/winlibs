
#ifndef ASTROLIB_EXPORT_H
#define ASTROLIB_EXPORT_H

#ifdef ASTROLIB_STATIC_DEFINE
#  define ASTROLIB_EXPORT
#  define ASTROLIB_NO_EXPORT
#else
#  ifndef ASTROLIB_EXPORT
#    ifdef astro_EXPORTS
        /* We are building this library */
#      define ASTROLIB_EXPORT __declspec(dllexport)
#    else
        /* We are using this library */
#      define ASTROLIB_EXPORT __declspec(dllimport)
#    endif
#  endif

#  ifndef ASTROLIB_NO_EXPORT
#    define ASTROLIB_NO_EXPORT 
#  endif
#endif

#ifndef ASTROLIB_DEPRECATED
#  define ASTROLIB_DEPRECATED __declspec(deprecated)
#endif

#ifndef ASTROLIB_DEPRECATED_EXPORT
#  define ASTROLIB_DEPRECATED_EXPORT ASTROLIB_EXPORT ASTROLIB_DEPRECATED
#endif

#ifndef ASTROLIB_DEPRECATED_NO_EXPORT
#  define ASTROLIB_DEPRECATED_NO_EXPORT ASTROLIB_NO_EXPORT ASTROLIB_DEPRECATED
#endif

#if 0 /* DEFINE_NO_DEPRECATED */
#  ifndef ASTROLIB_NO_DEPRECATED
#    define ASTROLIB_NO_DEPRECATED
#  endif
#endif

#endif /* ASTROLIB_EXPORT_H */
