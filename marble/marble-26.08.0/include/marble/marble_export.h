
#ifndef MARBLE_EXPORT_H
#define MARBLE_EXPORT_H

#ifdef MARBLE_STATIC_DEFINE
#  define MARBLE_EXPORT
#  define MARBLE_NO_EXPORT
#else
#  ifndef MARBLE_EXPORT
#    ifdef marblewidget_EXPORTS
        /* We are building this library */
#      define MARBLE_EXPORT __declspec(dllexport)
#    else
        /* We are using this library */
#      define MARBLE_EXPORT __declspec(dllimport)
#    endif
#  endif

#  ifndef MARBLE_NO_EXPORT
#    define MARBLE_NO_EXPORT 
#  endif
#endif

#ifndef MARBLE_DEPRECATED
#  define MARBLE_DEPRECATED __declspec(deprecated)
#endif

#ifndef MARBLE_DEPRECATED_EXPORT
#  define MARBLE_DEPRECATED_EXPORT MARBLE_EXPORT MARBLE_DEPRECATED
#endif

#ifndef MARBLE_DEPRECATED_NO_EXPORT
#  define MARBLE_DEPRECATED_NO_EXPORT MARBLE_NO_EXPORT MARBLE_DEPRECATED
#endif

#if 0 /* DEFINE_NO_DEPRECATED */
#  ifndef MARBLE_NO_DEPRECATED
#    define MARBLE_NO_DEPRECATED
#  endif
#endif

#endif /* MARBLE_EXPORT_H */
