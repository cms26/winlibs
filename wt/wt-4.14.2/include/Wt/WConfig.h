#ifndef WCONFIG_H
#define WCONFIG_H

// Version defines
#define WT_SERIES 4
#define WT_MAJOR  14
#define WT_MINOR  2

/*! \brief A constant that encodes the library version of %Wt
 *
 * You may use this constant to check for the version of %Wt at build-time.
 */
#define WT_VERSION (((WT_SERIES & 0xff) << 24) | ((WT_MAJOR & 0xff) << 16) | ((WT_MINOR & 0xff) << 8))
#define WT_VERSION_STR "4.14.2"
#define WT_CLASS       "Wt4_14_2"
#define WT_INCLUDED_VERSION Wt_4_14_2

#define RUNDIR "c:/witty"
#define WT_CONFIG_XML "c:/witty/wt_config.xml"
#define WTHTTP_CONFIGURATION "c:/witty/wthttpd"

#define WT_STATIC
#define WTDBO_STATIC
#define WTDBOPOSTGRES_STATIC
#define WTDBOSQLITE3_STATIC
#define WTDBOFIREBIRD_STATIC
#define WTDBOMYSQL_STATIC
#define WTDBOMSSQLSERVER_STATIC
#define WTHTTP_STATIC

#define WT_HAS_WRASTERIMAGE
/* #undef WT_HAS_WPDFIMAGE */
/* #undef WT_WITH_SSL */
/* #undef WT_HAS_SAML */

/* #undef WT_USE_OPENGL */
/* #undef WT_DEBUG_ENABLED */
#define WT_THREADED

/* #undef WT_ANY_IS_THELINK2012_ANY */
/* #undef WT_ANY_IS_EXPERIMENTAL_ANY */
#define WT_ANY_IS_STD_ANY

#define WT_FILESYSTEM_IMPL_BOOST
/* #undef WT_FILESYSTEM_IMPL_STD */
/* #undef WT_FILESYSTEM_IMPL_STD_CLOCK_17 */

#define WT_DATE_TZ_USE_DATE
/* #undef WT_DATE_TZ_USE_STD */

#define WT_ASIO_IS_BOOST_ASIO
/* #undef WT_ASIO_IS_STANDALONE_ASIO */

/* #undef WT_TEST_VISIBILITY */

// our win32: WIN32 (gcc) or _WIN32 (MSC)
#if defined(WIN32) || defined(_WIN32)
#define WT_WIN32 1
#endif

#endif
