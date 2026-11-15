#!/usr/bin/env bash

set -euo pipefail

TOOL_NAME="tomcat"
TOOL_CMD="catalina.sh"

# Directory inside an installation that goes to PATH, holds a link to bin/catalina.sh only:
# the other scripts in bin/ have generic names (version.sh, startup.sh, digest.sh).
PATH_DIR="asdf-bin"

# Releases older than Tomcat 6 have incomplete or differently named archives.
MIN_MAJOR_VERSION=6

# The CDN serves current releases only, the archive serves all of them.
CDN_URL="https://dlcdn.apache.org/tomcat"
ARCHIVE_URL="https://archive.apache.org/dist/tomcat"

# Strongest first; old releases have sha1 or md5 only.
CHECKSUM_TYPES=(sha512 sha1 md5)

curl_opts=(-fsSL)

fail() {
	echo -e "asdf-$TOOL_NAME: $*" >&2
	exit 1
}

warn() {
	echo -e "asdf-$TOOL_NAME: $*" >&2
}

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1n -k 2,2n -k 3,3n | awk '{print $2}'
}

list_major_versions() {
	curl "${curl_opts[@]}" "$ARCHIVE_URL/" |
		grep -o 'href="tomcat-[0-9]\+/"' |
		grep -o '[0-9]\+' |
		awk -v min="$MIN_MAJOR_VERSION" '$1 >= min'
}

# Stable releases only: milestones, betas and RCs (9.0.0.M1, 10.0.0-M1, 8.0.0-RC1) are skipped.
list_all_versions() {
	local major_version index
	for major_version in $(list_major_versions); do
		index=$(curl "${curl_opts[@]}" "$ARCHIVE_URL/tomcat-$major_version/")
		echo "$index" |
			{ grep -o 'href="v[^"]*/"' || true; } |
			sed -n "s#^href=\"v\($major_version\.[0-9.]*[0-9]\)/\"\$#\1#p"
	done
}

# Latest stable version matching the query: "9" gives 9.0.x, "8.5" gives 8.5.x.
latest_version() {
	local query="$1"
	list_all_versions |
		awk -v query="$query" 'query == "" || $0 == query || index($0, query ".") == 1' |
		sort_versions | tail -n1
}

release_path() {
	local version="$1"
	echo "tomcat-${version%%.*}/v$version/bin/apache-tomcat-$version.tar.gz"
}

# GNU coreutils on Linux, shasum and md5 on macOS.
checksum_of() {
	local checksum_type="$1" file="$2"
	if command -v "${checksum_type}sum" >/dev/null; then
		"${checksum_type}sum" "$file"
	elif [ "$checksum_type" = md5 ]; then
		md5 -r "$file"
	else
		shasum -a "${checksum_type#sha}" "$file"
	fi | awk '{print $1}'
}

verify_checksum() {
	local file="$1" base_url="$2" path="$3"
	local checksum_type expected actual
	for checksum_type in "${CHECKSUM_TYPES[@]}"; do
		expected=$(curl "${curl_opts[@]}" "$base_url/$path.$checksum_type" 2>/dev/null ||
			curl "${curl_opts[@]}" "$ARCHIVE_URL/$path.$checksum_type" 2>/dev/null) || continue
		expected=$(echo "$expected" | awk '{print tolower($1); exit}')
		actual=$(checksum_of "$checksum_type" "$file")
		[ "$actual" = "$expected" ] || fail "$checksum_type checksum mismatch for $file: expected $expected, got $actual"
		echo "* $checksum_type checksum verified"
		return 0
	done
	warn "No checksum published for $path, skipping verification"
}

download_release() {
	local version="$1" filename="$2"
	local path base_url
	path=$(release_path "$version")

	echo "* Downloading $TOOL_NAME release $version..."
	for base_url in "$CDN_URL" "$ARCHIVE_URL"; do
		if curl "${curl_opts[@]}" -o "$filename" "$base_url/$path" 2>/dev/null; then
			verify_checksum "$filename" "$base_url" "$path"
			return 0
		fi
	done
	fail "Could not download $ARCHIVE_URL/$path"
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="$3"

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	# A chain, not a subshell: set -e does not work inside "( ... ) || ...".
	if ! {
		mkdir -p "$install_path/$PATH_DIR" &&
			cp -R "$ASDF_DOWNLOAD_PATH"/. "$install_path" &&
			test -x "$install_path/bin/$TOOL_CMD" &&
			ln -sf "../bin/$TOOL_CMD" "$install_path/$PATH_DIR/$TOOL_CMD"
	}; then
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	fi

	echo "$TOOL_NAME $version installation was successful!"
	echo "Tomcat path: $install_path"
}
