# Created by: q5sys
# $FreeBSD$

PORTNAME=       zelta
DISTVERSIONPREFIX=  v
DISTVERSION=    0.5
DISTVERSIONSUFFIX=  -beta
CATEGORIES=     sysutils
DISTNAME=       ${PORTNAME}-${DISTVERSIONPREFIX}${DISTVERSION}${DISTVERSIONSUFFIX}
MASTER_SITES=   GH

MAINTAINER=     jt@obs-sec.com
COMMENT=        Zelta Replication Suite

LICENSE=        BSD2CLAUSE

USE_GITHUB=     yes
GH_ACCOUNT=     q5sys
GH_PROJECT=     zelta
GH_TAGNAME=     v0.5-beta

NO_BUILD=yes

DESTDIR?=       # None
PREFIX?=        /usr/local

ZELTA_BIN?=     ${PREFIX}/bin
ZELTA_ETC?=     ${PREFIX}/etc/zelta
ZELTA_SHARE?=   ${PREFIX}/share/zelta

ZELTA_CONF?=    zelta.conf
ZELTA_ENV?=     zelta.env
ZELTA_PROG?=    zelta

.PHONY: install
install:
        mkdir -p "${DESTDIR}${ZELTA_BIN}"
        cp "bin/${ZELTA_PROG}" "${DESTDIR}${ZELTA_BIN}/${ZELTA_PROG}"
        chmod 0755 "${DESTDIR}${ZELTA_BIN}/${ZELTA_PROG}"
        (cd "${DESTDIR}" && ln -fs "${ZELTA_BIN}/${ZELTA_PROG}" "${ZELTA_BIN}/zmatch")
        (cd "${DESTDIR}" && ln -fs "${ZELTA_BIN}/${ZELTA_PROG}" "${ZELTA_BIN}/zp")
        (cd "${DESTDIR}" && ln -fs "${ZELTA_BIN}/${ZELTA_PROG}" "${ZELTA_BIN}/zpull")

        mkdir -p "${DESTDIR}${ZELTA_ETC}"
        cp "bin/${ZELTA_ENV}" "${DESTDIR}${ZELTA_ETC}/${ZELTA_ENV}.example"
        chmod 0755 "${DESTDIR}${ZELTA_ETC}/${ZELTA_ENV}.example"
        cp "bin/${ZELTA_ENV}" "${DESTDIR}${ZELTA_ETC}/${ZELTA_ENV}"
        chmod 0755 "${DESTDIR}${ZELTA_ETC}/${ZELTA_ENV}"
        cp "bin/${ZELTA_CONF}" "${DESTDIR}${ZELTA_ETC}/${ZELTA_CONF}"
        chmod 0644 "${DESTDIR}${ZELTA_ETC}/${ZELTA_CONF}"

        mkdir -p "${DESTDIR}${ZELTA_SHARE}"
        find share/zelta -name '*.awk' -o -name '*.sh' | while read -r file; do \
                cp "$$file" "${DESTDIR}${ZELTA_SHARE}/$$(basename "$$file")" \
        done

.include <bsd.port.mk>
