TERMUX_PKG_HOMEPAGE=https://github.com/decathorpe/mitmproxy_wireguard
TERMUX_PKG_DESCRIPTION="WireGuard frontend for mitmproxy"
TERMUX_PKG_LICENSE="MIT"
TERMUX_PKG_MAINTAINER="@termux-user-repository"
TERMUX_PKG_VERSION="0.1.19"
TERMUX_PKG_SRCURL=https://github.com/decathorpe/mitmproxy_wireguard/archive/refs/tags/$TERMUX_PKG_VERSION.tar.gz
TERMUX_PKG_SHA256=749b5b45222b629f4cced154cc4bf70ba7ae3061db02e2ea0ae45a4ae6246463
TERMUX_PKG_AUTO_UPDATE=true
TERMUX_PKG_DEPENDS="libc++, openssl, python"
TERMUX_PKG_BUILD_IN_SRC=true
TERMUX_PKG_UPDATE_TAG_TYPE="newest-tag"

tur_elf_cleaner_for_wheel() {
	local filename="$(realpath $1)"

	# Make a workspace and enter it
	local work_dir="$(mktemp -d)"
	pushd $work_dir

	# Wheel file is actually a zip file, unzip it first.
	unzip -q $filename

	# Run elf-cleaner in the workspace
	find . -type f -print0 | xargs -r -0 \
			"$TERMUX_ELF_CLEANER" --api-level $TERMUX_PKG_API_LEVEL

	# Re-zip the file
	zip -q -r $filename *

	# Clean up the workspace
	popd
	rm -rf $work_dir
}

termux_step_pre_configure() {
	_PYTHON_VERSION=$(. $TERMUX_SCRIPTDIR/packages/python/build.sh; echo $_MAJOR_VERSION)

	termux_setup_rust

	termux_setup_python_crossenv
	pushd $TERMUX_PYTHON_CROSSENV_SRCDIR
	_CROSSENV_PREFIX=$TERMUX_PKG_BUILDDIR/python-crossenv-prefix
	python${_PYTHON_VERSION} -m crossenv \
		$TERMUX_PREFIX/bin/python${_PYTHON_VERSION} \
		${_CROSSENV_PREFIX}
	popd
	. ${_CROSSENV_PREFIX}/bin/activate

	build-pip install maturin

	LDFLAGS+=" -Wl,--no-as-needed -lpython${_PYTHON_VERSION}"
}

termux_step_make_install() {
	export CARGO_BUILD_TARGET=${CARGO_TARGET_NAME}
	export PYO3_CROSS_LIB_DIR=$TERMUX_PREFIX/lib
	export PYTHONPATH=$TERMUX_PREFIX/lib/python${_PYTHON_VERSION}/site-packages

	build-python -m maturin build --release --skip-auditwheel --target $CARGO_BUILD_TARGET

	# Fix wheel name for arm
	if [ "$TERMUX_ARCH" = "arm" ]; then
		mv ./target/wheels/mitmproxy_wireguard-$TERMUX_PKG_VERSION-cp37-abi3-linux_armv7l.whl \
			./target/wheels/mitmproxy_wireguard-$TERMUX_PKG_VERSION-py37-none-any.whl
	fi

	pip install --no-deps ./target/wheels/*.whl --prefix $TERMUX_PREFIX

	# Recover the wheel name
	if [ "$TERMUX_ARCH" = "arm" ]; then
		mv ./target/wheels/mitmproxy_wireguard-$TERMUX_PKG_VERSION-py37-none-any.whl \
			./target/wheels/mitmproxy_wireguard-$TERMUX_PKG_VERSION-cp37-abi3-linux_armv7l.whl
	fi
}

termux_step_post_massage() {
	pushd $TERMUX_PKG_BUILDDIR

	# Run elf-cleaner for wheels
	shopt -s nullglob
	local _whl
	for _whl in ./target/wheels/*.whl; do
		tur_elf_cleaner_for_wheel $_whl
	done
	shopt -u nullglob

	cp ./target/wheels/*.whl $TERMUX_SCRIPTDIR/output/
	popd
}