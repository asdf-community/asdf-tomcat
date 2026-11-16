#!/usr/bin/env bats

# Offline tests: curl is replaced with a function that serves the pages in fixtures/.
# bats runs each test in a subshell, the curl stubs are called by the sourced code.
# shellcheck disable=SC2030,SC2031,SC2329

setup() {
	PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
	FIXTURES="$BATS_TEST_DIRNAME/fixtures"
	export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/cache"
	CURL_LOG="$BATS_TEST_TMPDIR/curl.log"
	# shellcheck source=lib/utils.bash
	source "$PLUGIN_DIR/lib/utils.bash"
}

curl() {
	local url="${*: -1}"
	echo "$url" >>"$CURL_LOG"
	case "$url" in
	"$ARCHIVE_URL/") cat "$FIXTURES/archive-index.html" ;;
	"$ARCHIVE_URL/tomcat-6/") cat "$FIXTURES/tomcat-6-index.html" ;;
	"$ARCHIVE_URL/tomcat-9/") cat "$FIXTURES/tomcat-9-index.html" ;;
	*) return 22 ;;
	esac
}

curl_calls() {
	wc -l <"$CURL_LOG" | tr -d ' '
}

@test "list_all_versions lists stable versions of Tomcat 6 and later" {
	run list_all_versions
	[ "$status" -eq 0 ]
	[ "$(echo "$output" | sort_versions | xargs echo)" = "6.0.0 6.0.53 9.0.1 9.0.2 9.0.10 9.0.100 9.0.124" ]
}

@test "list_all_versions caches the list" {
	list_all_versions >/dev/null
	local calls
	calls=$(curl_calls)
	list_all_versions >/dev/null
	[ "$(curl_calls)" -eq "$calls" ]
}

@test "list_all_versions does not cache with CACHE_TTL=0" {
	CACHE_TTL=0
	list_all_versions >/dev/null
	local calls
	calls=$(curl_calls)
	list_all_versions >/dev/null
	[ "$(curl_calls)" -gt "$calls" ]
}

@test "list_all_versions fails and caches nothing when a page fails" {
	# The index and Tomcat 6 succeed, Tomcat 9 fails: a partial list must not be cached.
	curl() {
		case "${*: -1}" in
		"$ARCHIVE_URL/") cat "$FIXTURES/archive-index.html" ;;
		"$ARCHIVE_URL/tomcat-6/") cat "$FIXTURES/tomcat-6-index.html" ;;
		*) return 22 ;;
		esac
	}
	run list_all_versions
	[ "$status" -ne 0 ]
	[ ! -s "$CACHE_DIR/versions" ]
}

@test "sort_versions sorts numerically" {
	run sort_versions < <(printf '%s\n' 10.1.10 9.0.100 10.1.9 9.0.99 11.0.1)
	[ "$(echo "$output" | xargs echo)" = "9.0.99 9.0.100 10.1.9 10.1.10 11.0.1" ]
}

@test "latest_version without a query is the newest version" {
	run latest_version ""
	[ "$output" = "9.0.124" ]
}

@test "latest_version matches whole version components" {
	[ "$(latest_version 9)" = "9.0.124" ]
	[ "$(latest_version 6.0)" = "6.0.53" ]
	[ "$(latest_version 9.0.1)" = "9.0.1" ]
	[ "$(latest_version 9.0.10)" = "9.0.10" ]
	[ -z "$(latest_version 7)" ]
}

@test "verify_checksum accepts a matching checksum" {
	local file="$BATS_TEST_TMPDIR/archive.tar.gz" published
	echo data >"$file"
	published=$(sha512sum "$file" 2>/dev/null || shasum -a 512 "$file")
	curl() { echo "$published"; }
	run verify_checksum "$file" "$ARCHIVE_URL" "path"
	[ "$status" -eq 0 ]
	[[ "$output" == *"sha512 checksum verified"* ]]
}

@test "verify_checksum fails on a mismatch" {
	local file="$BATS_TEST_TMPDIR/archive.tar.gz"
	echo data >"$file"
	curl() { echo "0000 *archive.tar.gz"; }
	run verify_checksum "$file" "$ARCHIVE_URL" "path"
	[ "$status" -eq 1 ]
	[[ "$output" == *"sha512 checksum mismatch"* ]]
}

@test "verify_checksum falls back to sha1 when sha512 is not published" {
	local file="$BATS_TEST_TMPDIR/archive.tar.gz" published
	echo data >"$file"
	published=$(sha1sum "$file" 2>/dev/null || shasum -a 1 "$file")
	curl() { [[ "${*: -1}" == *.sha1 ]] && echo "$published"; }
	run verify_checksum "$file" "$ARCHIVE_URL" "path"
	[ "$status" -eq 0 ]
	[[ "$output" == *"sha1 checksum verified"* ]]
}

@test "verify_checksum is skipped with ASDF_TOMCAT_SKIP_CHECKSUM" {
	local file="$BATS_TEST_TMPDIR/archive.tar.gz"
	echo data >"$file"
	curl() { echo "0000 *archive.tar.gz"; }
	ASDF_TOMCAT_SKIP_CHECKSUM=1 run verify_checksum "$file" "$ARCHIVE_URL" "path"
	[ "$status" -eq 0 ]
}

@test "ASDF_TOMCAT_MIRROR replaces the CDN" {
	ASDF_TOMCAT_MIRROR=https://mirror.example.com/tomcat run bash -c "source '$PLUGIN_DIR/lib/utils.bash'; echo \$CDN_URL"
	[ "$output" = "https://mirror.example.com/tomcat" ]
}

@test "install_version links catalina.sh only" {
	export ASDF_DOWNLOAD_PATH="$BATS_TEST_TMPDIR/download"
	mkdir -p "$ASDF_DOWNLOAD_PATH/bin"
	printf '#!/bin/sh\n' >"$ASDF_DOWNLOAD_PATH/bin/catalina.sh"
	printf '#!/bin/sh\n' >"$ASDF_DOWNLOAD_PATH/bin/startup.sh"
	chmod +x "$ASDF_DOWNLOAD_PATH"/bin/*.sh
	run install_version version 9.0.124 "$BATS_TEST_TMPDIR/install"
	[ "$status" -eq 0 ]
	[ "$(ls "$BATS_TEST_TMPDIR/install/$PATH_DIR")" = "catalina.sh" ]
	[ -x "$BATS_TEST_TMPDIR/install/$PATH_DIR/catalina.sh" ]
}

@test "install_version removes the installation when catalina.sh is missing" {
	export ASDF_DOWNLOAD_PATH="$BATS_TEST_TMPDIR/download"
	mkdir -p "$ASDF_DOWNLOAD_PATH/bin"
	run install_version version 9.0.124 "$BATS_TEST_TMPDIR/install"
	[ "$status" -eq 1 ]
	[ ! -e "$BATS_TEST_TMPDIR/install" ]
}

@test "the download directory is emptied after a failure" {
	export ASDF_DOWNLOAD_PATH="$BATS_TEST_TMPDIR/download"
	mkdir -p "$ASDF_DOWNLOAD_PATH/partial"
	touch "$ASDF_DOWNLOAD_PATH/archive.tar.gz"
	run bash -c "source '$PLUGIN_DIR/lib/utils.bash'; trap clean_download_path_on_failure EXIT; false"
	[ "$status" -eq 1 ]
	[ -d "$ASDF_DOWNLOAD_PATH" ]
	[ -z "$(ls -A "$ASDF_DOWNLOAD_PATH")" ]
}

@test "list-bin-paths keeps bin for versions installed by plugin 1.x" {
	mkdir -p "$BATS_TEST_TMPDIR/old/bin" "$BATS_TEST_TMPDIR/new/$PATH_DIR"
	[ "$(ASDF_INSTALL_PATH="$BATS_TEST_TMPDIR/old" "$PLUGIN_DIR/bin/list-bin-paths")" = "bin" ]
	[ "$(ASDF_INSTALL_PATH="$BATS_TEST_TMPDIR/new" "$PLUGIN_DIR/bin/list-bin-paths")" = "$PATH_DIR" ]
}

@test "exec-env sets CATALINA_HOME to the installation" {
	run bash -c "CATALINA_HOME=/stale ASDF_INSTALL_PATH=/opt/tomcat; source '$PLUGIN_DIR/bin/exec-env'; echo \$CATALINA_HOME"
	[ "$output" = "/opt/tomcat" ]
}
