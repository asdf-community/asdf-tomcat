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
# ASDF_TOMCAT_MIRROR replaces the CDN, e.g. https://mirror.example.com/apache/tomcat.
CDN_URL="${ASDF_TOMCAT_MIRROR:-https://dlcdn.apache.org/tomcat}"
ARCHIVE_URL="https://archive.apache.org/dist/tomcat"

# asdf does not cache version lists, and the archive is slow and rate limited:
# the list is kept for an hour, ASDF_TOMCAT_CACHE_TTL sets seconds, 0 disables.
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/asdf-$TOOL_NAME"
CACHE_TTL="${ASDF_TOMCAT_CACHE_TTL:-3600}"

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

file_age() {
	local modified
	modified=$(stat -c %Y "$1" 2>/dev/null || stat -f %m "$1")
	echo $(($(date +%s) - modified))
}

# Prints the cached output of the command, runs it when the cache is missing or expired.
cached() {
	local name="$1" file tmp
	shift
	file="$CACHE_DIR/$name"
	if [ "$CACHE_TTL" -gt 0 ] && [ -s "$file" ] && [ "$(file_age "$file")" -lt "$CACHE_TTL" ]; then
		cat "$file"
		return 0
	fi
	mkdir -p "$CACHE_DIR"
	tmp=$(mktemp "$file.XXXXXX")
	if "$@" >"$tmp" && [ -s "$tmp" ]; then
		mv "$tmp" "$file"
		cat "$file"
	else
		rm -f "$tmp"
		return 1
	fi
}

list_all_versions() {
	cached versions fetch_all_versions
}

# Stable releases only: milestones, betas and RCs (9.0.0.M1, 10.0.0-M1, 8.0.0-RC1) are skipped.
# Called inside "if" by cached, where set -e does not work: every failure returns explicitly,
# so that a partial list is not cached.
fetch_all_versions() {
	local major_versions major_version index
	major_versions=$(list_major_versions) || return 1
	for major_version in $major_versions; do
		index=$(curl "${curl_opts[@]}" "$ARCHIVE_URL/tomcat-$major_version/") || return 1
		echo "$index" |
			{ grep -o 'href="v[^"]*/"' || true; } |
			sed -n "s#^href=\"v\($major_version\.[0-9.]*[0-9]\)/\"\$#\1#p"
	done
}

# Latest stable version matching the query: "9" gives 9.0.x, "8.5" gives 8.5.x.
latest_version() {
	local query="$1"
	list_all_versions |
		awk -v query="$query" 'query == "" || $0 "" == query "" || index($0, query ".") == 1' |
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
	if [ -n "${ASDF_TOMCAT_SKIP_CHECKSUM:-}" ]; then
		warn "ASDF_TOMCAT_SKIP_CHECKSUM is set, skipping verification"
		return 0
	fi
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

# asdf expects nothing left in the download directory after a failed download.
clean_download_path_on_failure() {
	local status=$?
	if [ "$status" -ne 0 ] && [ -n "${ASDF_DOWNLOAD_PATH:-}" ] && [ -d "$ASDF_DOWNLOAD_PATH" ]; then
		find "$ASDF_DOWNLOAD_PATH" -mindepth 1 -delete
	fi
	return "$status"
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
