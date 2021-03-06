#!/bin/bash -e
if [ -z "$4" ]; then
	echo 'must specify pack name, pack display name, target path, and mc version (with optional pack version)'
	exit 1
fi
pack_name="$1"
pack_display_name="$2"
target="$3"
mc_version="$4"
version="$5"
if [ -z "$version" ]; then
	if [ -n "$BUILD_NUMBER" ]; then
		echo Using Jenkins build number for pack version
		version="build.$BUILD_NUMBER"
	else
		echo Using current Unix timestamp for pack version
		version="ts.$(date '+%s')"
	fi
fi

rm -rf skcraft-modpack upload
mkdir skcraft-modpack
cp -r modpack/src skcraft-modpack/src
cp -r modpack/loaders skcraft-modpack/loaders

cat > skcraft-modpack/modpack.json <<EOF
{
  "name" : "$pack_name",
  "title" : "$pack_display_name",
  "gameVersion" : "$mc_version",
  "features" : [ ],
  "userFiles" : {
    "include" : [
      "options.txt",
      "optionsof.txt",
      "optionsshaders.txt",
      "config/fruitphone.cfg",
      "config/chiselsandbits_clipboard.cfg"
    ],
    "exclude" : [ ]
  },
  "launch" : {
    "flags" : [
      "-Dfml.ignoreInvalidMinecraftCertificates=true"
    ]
  }
}
EOF

java -jar skcraft.jar --version "$version" --input skcraft-modpack --output upload --manifest-dest upload/$pack_name.json

tmp=`mktemp`
# if this fails, instances.json doesn't exist, that's fine
rsync "$target/instances.json" $tmp || true

if [ ! -e "$tmp" -o -z "$(cat $tmp)" ]; then
	echo '{"minimumVersion":1,"packages":[]}' > $tmp
fi

# jq is magical
jq -r '.packages | map(select(.name != "'"$pack_name"'")) | .[length] = {title:"'"$pack_display_name"'",name:"'"$pack_name"'",version:"'$version'",location:"'"$pack_name"'.json",priority:1} | {minimumVersion:1,packages:.}' "$tmp" > upload/instances.json

# this trailing slash is VERY IMPORTANT
rsync -r upload/ "$target"

rm $tmp
