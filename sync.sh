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
    -a=*|--assets-dir=*)
    readonly ASSETS_DIR="${i#*=}"
    shift # past argument=value
    ;;
    *)
		echo "Unknown option '${i#*=}', aborting..."
		exit
    ;;
esac
done

readonly GIT_DIR=$(realpath ./git)
readonly GIT_ASSETS_DIR="$GIT_DIR/${ASSETS_DIR:=.wordpress.org}"
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

  svn add --force --quiet .

  if [ -d "$ASSETS_DIR" ]; then
    svn del --force --quiet "$ASSETS_DIR"
  fi

  find . -type f -name "*.png" \
    | awk '{print $0 "@"}' \
    | xargs svn propset --quiet --force svn:mime-type image/png

  find . -type f -name "*.jpg" \
    | awk '{print $0 "@"}' \
    | xargs svn propset --quiet --force svn:mime-type image/jpeg

  # Untrack files that have been deleted.
  # We add an at symbol to every name.
  # See http://stackoverflow.com/questions/1985203/why-subversion-skips-files-which-contain-the-symbol#1985366
  svn status \
    | grep -v "^[ \t]*\..*" \
    | grep "^\!" \
    | awk '{print $2 "@"}' \
    | xargs svn del --force --quiet

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
    rsync --compress --recursive --delete --delete-excluded --force --archive --exclude-from "$excludeFrom" "$source" "$destination"
  else
    rsync --compress --recursive --delete --delete-excluded --force --archive "$source" "$destination"
  fi
}

sync_tag () {
	local tag=$1

	if [ -d "$SVN_DIR/tags/$tag" ]; then
		# Tag is already part of the SVN repository, stop here.
		return
	fi

	cd "$GIT_DIR" || exit

	echo "Checking out 'tags/$tag'."
	git checkout "tags/$tag" > /dev/null 2>&1

	echo "Copying files over to svn repository in folder $SVN_DIR/tags/$tag."
	mkdir "$SVN_DIR/tags/$tag"
  sync_files . "$SVN_DIR/tags/$tag"

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

	echo "Copying files over to svn repository in folder $SVN_TRUNK_DIR."
	sync_files . "$SVN_TRUNK_DIR"

	cd "$SVN_TRUNK_DIR" || exit
	stage_and_commit_changes "Updating trunk"
}

sync_assets () {
	cd "$GIT_DIR" || exit
	git checkout master > /dev/null 2>&1

	if [ -d "$GIT_ASSETS_DIR" ]; then
		sync_files "$GIT_ASSETS_DIR" "$SVN_ASSETS_DIR"
	fi

	cd "$SVN_ASSETS_DIR" || exit

	stage_and_commit_changes "Updating assets"
}

fetch_svn_repo
fetch_git_repo
sync_assets
sync_all_tags
sync_trunk

exit 0
