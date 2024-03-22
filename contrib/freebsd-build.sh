#!/usr/bin/env bash
set -e
set -u

warn() {
	echo "$@" >&2
}
error() {
	warn "$@"
	exit 1
}

VENDOR_DIR=${LMS_BUILD_VENDOR_DIR:-../repo-vendor}
OUT_DIR=${LMS_BUILD_OUT_DIR:-}

CONF_FILES='convert.conf types.conf'
DOC_FILES='Changelog*.html License*.txt'
SUBST_KEYS='PORTNAME PREFIX SLIMDIR SLIMDBDIR SITE_PERL SLIMUSER SLIMGROUP PERL CONFFILES'

: ${LMS_BUILD_SUBST_PORTNAME:='logitechmediaserver'}
# These must be supplied via env vars (or edit this file)
: ${LMS_BUILD_SUBST_PREFIX:='/usr/local'}
: ${LMS_BUILD_SUBST_SLIMDIR:='share/logitechmediaserver'}
: ${LMS_BUILD_SUBST_SLIMDBDIR:='/var/db/logitechmediaserver'}
: ${LMS_BUILD_SUBST_SITE_PERL:='/usr/local/lib/perl5/site_perl'}
: ${LMS_BUILD_SUBST_SLIMUSER:='slimserv'}
: ${LMS_BUILD_SUBST_SLIMGROUP:='slimserv'}
: ${LMS_BUILD_SUBST_PERL:=$(which perl)}
: ${LMS_BUILD_SUBST_CONFFILES:=$CONF_FILES}

# Always build from toplevel dir
cd "$(dirname "$0")/.."
echo "Changed dir to $(pwd)"

#{{{ Do some sanity checks
if ! [ -e "$VENDOR_DIR" ]
then
	warn "Expected dir to exist: $(pwd)/$VENDOR_DIR"
	warn "It should be a clone of https://github.com/LMS-Community/slimserver-vendor"
	error "Cannot continue"
fi

if [ -z "$OUT_DIR" ]
then
	error "You must specify LMS_BUILD_OUT_DIR (or edit this script)"
else
	echo "OUT_DIR: $OUT_DIR"
fi

set +u
for subst in $SUBST_KEYS
do
	var="LMS_BUILD_SUBST_$subst"
	if [ -z "${!var}" ]
	then
		error "You must specify $var (or edit this script)"
	else
		echo "$var: ${!var}"
	fi
done
set -u

#}}}

OUT_DIR_SLIMDIR=$OUT_DIR/logitechmediaserver
OUT_DIR_FILES=$OUT_DIR/files
PERL_VER=$(perl -V | head -n1 | sed 's/.*(revision \([0-9]*\) version \([0-9]*\).*/\1.\2/')
echo "Perl version: $PERL_VER"

# The steps chain together. We allow skipping ahead by
# providing an arg naming the step to start with.
firstStep=${1:-begin}

step_begin() {
	echo "Step: begin"
	step_build_vendor
}
step_build_vendor() {
	echo "Step: build_vendor"
	(
		cd "$VENDOR_DIR/CPAN"
		# Note: important to use 'env' since the enclosing
		# environment might have PERL_XXX vars that could
		# cause things to be installed in the wrong places.
		env -i "PATH=$PATH" ./buildme.sh
	)
	step_populate_main
}
step_populate_main() {
	echo "Step: populate_main"

	mkdir -p "$OUT_DIR_SLIMDIR"

	(
		srcdir=$(pwd)
		echo "Copy from '$srcdir' to '$OUT_DIR_SLIMDIR'"
		rsync -v -a \
			--delete-excluded \
			--exclude '.git/' \
			--exclude '.github/' \
			--exclude '*.orig' \
			--exclude '*.bak' \
			--exclude '*.packlist' \
			--exclude 'Bin/' \
			--exclude "$PERL_VER/MSWin32-x64-multi-thread/" \
			--exclude "$PERL_VER/arm-linux-gnueabihf-thread-multi-64int/" \
			--exclude "$PERL_VER/aarch64-linux-thread-multi/" \
			--exclude "$PERL_VER/i386-linux-thread-multi-64int/" \
			--exclude "$PERL_VER/x86_64-linux-thread-multi/" \
			"$srcdir/" "$OUT_DIR_SLIMDIR"
	)

	step_populate_vendor
	#step_end
}
step_populate_vendor() {
	echo "Step: populate_vendor"

	mkdir -p "$OUT_DIR_SLIMDIR/CPAN"

	(
		cd "$VENDOR_DIR/CPAN/build"
		cp -v -a arch "$OUT_DIR_SLIMDIR/CPAN"
		cp -v -a "$PERL_VER/lib/perl5" "$OUT_DIR_SLIMDIR/CPAN/arch/$PERL_VER/"

		# Note: some are commented out since the 'rsync --exclude ...' takes care of them.

		cd "$OUT_DIR_SLIMDIR"
		#find . -name \*.orig -delete -o -name \*.bak -delete -o -name \*.packlist -delete
		find ./CPAN/arch/ ! -path "./CPAN/arch/${PERL_VER}*" -delete
		#rm -r -- Bin/* .editorconfig .github
		#rm -- ${CONF_FILES} ${DOC_FILES}
		rm -- ${DOC_FILES}

		#cd "$OUT_DIR_SLIMDIR/CPAN/arch/$PERL_VER"
		#rm -r -- arm-linux-gnueabihf-thread-multi-64int
		#rm -r -- aarch64-linux-thread-multi
		#rm -r -- i386-linux-thread-multi-64int
		#rm -r -- x86_64-linux-thread-multi
	)

	step_make_samples
}
step_make_samples() {
	echo "Step: make_samples"
	(
		# These seem kinda pointless, but meh.
		cd "$OUT_DIR_SLIMDIR"
		for f in $CONF_FILES
		do
			cp "$f" "$f.sample"
		done
	)
	step_local_substitutions
}
do_substitutions() {
	src=$1
	dest=${2%%.in}
	cp -v "$src" "$dest"
	for key in $SUBST_KEYS
	do
		var="LMS_BUILD_SUBST_$key"
		val=${!var}
		echo "SUBST $key ..."
		sed -e "s!%%$key%%!$val!g" -i '' "$dest"
	done
}
step_local_substitutions() {
	echo "Step: local_substitutions"

	mkdir -p "$OUT_DIR_FILES"

	baseDir=contrib/freebsd-files
	mkdir -p "$baseDir/out"

	(
		cd "$baseDir"
		for f in *.in
		do
			do_substitutions "$f" "$OUT_DIR_FILES/$f"
		done
	)

	step_fix_shebang
}
step_fix_shebang() {
	echo "Step: fix_shebang"

	# TODO: have this more dynamic, rather than a fixed list.
	# E.g: grep for '^#!/usr/bin/perl' in the output dir.
	for f in \
		CPAN/Log/Log4perl/Layout/PatternLayout/Multiline.pm \
		Slim/Plugin/UPnP/t/MediaRenderer.t \
		Slim/Plugin/UPnP/t/MediaServer.t \
		lib/MPEG/Audio/Frame.pm \
		gdresized.pl \
		gdresize.pl \
		scanner.pl \
		slimserver.pl
	do
		sed -e "1s,#!/usr/bin/perl,#!/usr/local/bin/perl,g" -i '' "$OUT_DIR_SLIMDIR/$f"
	done

	step_chmod
}
step_chmod() {
	echo "Step: chmod"

	chmod +x "$OUT_DIR_FILES/logitechmediaserver"

	step_symlink
}
step_symlink() {
	echo "Step: symlink"

	if ! [ -L "$OUT_DIR_SLIMDIR/Cache" ]
	then
		ln -s "$LMS_BUILD_SUBST_SLIMDBDIR/cache" "$OUT_DIR_SLIMDIR/Cache"
	fi

	step_finalize
}
step_finalize() {
	echo "Step: finalize"

	if [ -e "$OUT_DIR_FILES/Custom.pm" ]
	then
		mv "$OUT_DIR_FILES/Custom.pm" "$OUT_DIR_SLIMDIR/Slim/Utils/OS/Custom.pm"
	fi
	if [ -e "$OUT_DIR_FILES/custom-convert.conf" ]
	then
		mv "$OUT_DIR_FILES/custom-convert.conf" "$OUT_DIR_SLIMDIR/"
	fi

	usr=$LMS_BUILD_SUBST_SLIMUSER
	grp=$LMS_BUILD_SUBST_SLIMGROUP
	usrgrp=$usr:$grp
	rootUsrGrp=root:wheel

	echo "Tasks for you to perform:"
	echo " * sudo chown -RH $usrgrp '$OUT_DIR_SLIMDIR'"
	echo " * sudo chmod g-w '$OUT_DIR_SLIMDIR'"
	echo " * sudo chown $rootUsrGrp '$OUT_DIR_FILES/logitechmediaserver'"
	echo " * sudo chown $rootUsrGrp '$OUT_DIR_FILES/logitechmediaserver.conf'"
	echo " * sudo cp -r $OUT_DIR_SLIMDIR $LMS_BUILD_SUBST_SLIMDIR"
	echo " * sudo cp $OUT_DIR_FILES/logitechmediaserver $LMS_BUILD_SUBST_PREFIX/etc/rc.d/"
	echo " * sudo cp $OUT_DIR_FILES/logitechmediaserver.conf $LMS_BUILD_SUBST_PREFIX/etc/newsyslog.conf.d/"

	if ! [ -e "$LMS_BUILD_SUBST_SLIMDBDIR" ]
	then
		echo " * create dir: $LMS_BUILD_SUBST_SLIMDBDIR"
	fi

	logDir="/var/log/$LMS_BUILD_SUBST_PORTNAME"
	if ! [ -e "$logDir" ]
	then
		echo " * sudo mkdir '$logDir'"
		echo " * sudo chown $usrgrp '$logDir'"
		echo " * sudo -u $usr touch '$logDir/server.log'"
	fi

	step_end
}
step_end() {
	echo "Step: end"
	echo "DONE"
}

eval "step_$firstStep"
