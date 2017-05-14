#!/usr/bin/env bash

set -eu

for i in "$@"
do
case $i in
    -p=*|--plugin-name=*)
    readonly PLUGIN_NAME="${i#*=}"
    shift # past argument=value
    ;;
    -g=*|--git-repo=*)
    readonly GIT_REPO="${i#*=}"
    shift # past argument=value
    ;;
    -u=*|--svn-user=*)
    readonly SVN_USER="${i#*=}"
    shift # past argument=value
    ;;
    *)
		echo "Unknown option '${i#*=}', aborting..."
		exit
    ;;
esac
done

readonly GIT_DIR=$(realpath ./git)
readonly SVN_DIR=$(realpath ./svn)
readonly SVN_ASSETS_DIR="$SVN_DIR/assets"
readonly SVN_TAGS_DIR="$SVN_DIR/tags"
readonly SVN_TRUNK_DIR="$SVN_DIR/trunk"
readonly SVN_REPO="https://plugins.svn.wordpress.org/$PLUGIN_NAME"

fetch_svn_repo () {
	rm -rf "$SVN_DIR"
	echo "Fetch clean SVN repository."
	if ! svn co "$SVN_REPO" "$SVN_DIR" > /dev/null; then
		echo "Unable to fetch content from SVN repository at URL $SVN_REPO."
		exit
	fi
	echo
}

fetch_git_repo () {
	rm -rf "$GIT_DIR"
	echo "Fetch clean GIT repository."
	if ! git clone "$GIT_REPO" "$GIT_DIR"; then
		echo "Unable to fetch content from GIT repository at URL $GIT_REPO."
		exit
	fi
	echo
}

stage_and_commit_changes () {
	local message=$1

	svn add . --force > /dev/null
	svn add ./* --force > /dev/null

  # Untrack files that have been deleted.
  svn status | grep -v "^.[ \t]*\..*" | grep "^\!" | awk '{print $2}' | xargs svn del

	changes=$(svn status -q)
	if [[ $changes ]]; then
		echo "Detected changes in $(pwd), about to commit them."
		svn commit --username="$SVN_USER" -m "$message"
	else
		echo "No changes detected changes in $(pwd)."
	fi
	echo
}

sync_files () {
  local source=$1/
  local destination=$2/
  local excludeFrom="$source.distignore"

  if [ -f "$excludeFrom" ]; then
    rsync --compress --archive --exclude-from "$excludeFrom" "$source" "$destination"
  else
    rsync --compress --archive "$source" "$destination"
  fi
}

sync_tag () {
	local tag=$1

	if [ -d "$SVN_DIR/tags/$tag" ]; then
		echo "Tag $tag is already part of the SVN repository."
		echo
		return
	fi

	cd "$GIT_DIR" || exit

	echo "Checking out 'tags/$tag'."
	git checkout "tags/$tag" > /dev/null 2>&1

	echo "Copying files over to svn repository in folder $SVN_DIR/tags/$tag."
	mkdir "$SVN_DIR/tags/$tag"
  sync_files . "$SVN_DIR/tags/$tag"
	rm -rf "$SVN_DIR/tags/$tag/assets"

	cd "$SVN_DIR/tags/$tag" || exit
	stage_and_commit_changes "Release tag $tag"
}

sync_all_tags () {
	cd "$GIT_DIR" || exit

	for tag in $(git tag); do
		sync_tag "$tag"
	done
}

sync_trunk () {
	cd "$GIT_DIR" || exit

	echo "Checking out master branch."
	git checkout master > /dev/null 2>&1

	echo "Erasing previous trunk."
	rm -rf "$SVN_TRUNK_DIR"
	# Todo: we also need to delete files from svn
	# svn del "$SVN_TRUNK_DIR"
	mkdir "$SVN_TRUNK_DIR"

	echo "Copying files over to svn repository in folder $SVN_TRUNK_DIR."
	sync_files . "$SVN_TRUNK_DIR"
	rm -rf "$SVN_TRUNK_DIR/assets"

	cd "$SVN_TRUNK_DIR" || exit
	stage_and_commit_changes "Updating trunk"
}

sync_assets () {
	cd "$GIT_DIR" || exit
	git checkout master > /dev/null 2>&1

	rm -rf "$SVN_ASSETS_DIR"
	mkdir "$SVN_ASSETS_DIR"

	if [ -d assets ]; then
		sync_files assets "$SVN_ASSETS_DIR"
	fi

	cd "$SVN_ASSETS_DIR" || exit
	echo "Setting correct mime-types for images."
	svn propset svn:mime-type image/png ./*.png || true
	svn propset svn:mime-type image/jpeg ./*.jpg || true

	stage_and_commit_changes "Updating assets"
}

fetch_svn_repo
fetch_git_repo
sync_assets
sync_all_tags
sync_trunk

exit 0
