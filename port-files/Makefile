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

do-install:
                cd ${WRKSRC} && ${SH} install.sh

.include <bsd.port.mk>
