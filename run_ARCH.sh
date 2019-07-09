#!/bin/bash
# ----------------------------------------------------------------------------------------------------------------------
# Restructure archival packages
# Note this restructuring is a natural transformation ( to a different folder ). The original folder and files are
# preserved.
#
# ----------------------------------------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------------------------------------
# Exit on error
# ----------------------------------------------------------------------------------------------------------------------
set -e

# ----------------------------------------------------------------------------------------------------------------------
# Get the directory
# ----------------------------------------------------------------------------------------------------------------------
D="$1"
NA="10622"

if [[ -z "$D" ]]
then
    echo "Need a directory as the first parameter."
    exit 1
fi

if [[ ! -d "$D" ]]
then
    echo "${D} is not a directory."
    exit 1
fi

if [[ ! -d "${D}/master" ]]
then
    echo "${D}/master expected. Could not find the subfolder 'master'"
    exit 1
fi

ARCHIVE=$(basename "$D")

# ----------------------------------------------------------------------------------------------------------------------
# Rename each file accordingly
# From ARCH12345_1_058.tif
# To ARCH12345.1_00058.tif
# ----------------------------------------------------------------------------------------------------------------------
function rename {
    package="$1"
    item_name="$2"
    echo "Rename ${package} for item ${item_name}"

    preservation_folder="${package}/preservation/"
    for f in "$preservation_folder"*
    do
        org_filename=$(basename "$f")    # e.g. ARCH12345_1_058.tif
        extension="${org_filename##*.}"          # tif
        filename="${org_filename%.*}"            # ARCH12345_1_058
        IFS=_ read arch item seq <<< "$filename" # ARCH12345 1 058
        seq="00000000000${seq}"
        seq="${seq:(-5)}"
        new_item="${ARCHIVE}.${item_name}_${seq}.${extension}"
        echo "Rename: ${org_filename} to ${new_item}"
        mv "$f" "${preservation_folder}/${new_item}"
    done
}

function mets {
    package="$1"
    item_name="$2"
    echo "Mets ${package} for item ${item_name}"

    metadata_folder="${package}/metadata"
    mkdir -p "$metadata_folder"
    mets_file="${metadata_folder}/mets_structmap.xml"
    echo "<?xml version=\"1.0\" encoding=\"utf-8\"?>
    <mets xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns=\"http://www.loc.gov/METS/\"
          xsi:schemaLocation=\"http://www.loc.gov/METS/ http://www.loc.gov/standards/mets/mets.xsd\">
        <structMap TYPE=\"logical\" ID=\"structMap_iish\" LABEL=\"IISH structure\">
            <div>" > "$mets_file"

    preservation_folder="${package}/preservation"
    for filename in $(ls ${preservation_folder})
    do
        org_filename="${filename%.*}"
        seq="${org_filename:(-5)}"
        seq=$((10#$seq))
        echo "<div TYPE=\"page\" ORDER=\"${seq}\" LABEL=\"Page ${seq}\">" >> "$mets_file"
        echo "<fptr CONTENTIDS=\"preservation/${filename}\" FILEID=\"${filename}\"></fptr>" >> "$mets_file"
        echo "</div>" >> "$mets_file"
    done

    echo "</div></structMap></mets>" >> "$mets_file"
}

function identifiers {
    package="$1"
    item_name="$2"
    echo "Identifiers ${package} for item ${item_name}"

    preservation_folder="${package}/preservation"
    metadata_folder="${package}/metadata"
    mkdir -p "$metadata_folder"
    identifiers_file="${metadata_folder}/identifiers.json"
    last=""
    echo "[" > "$identifiers_file"

    for filename in $(ls ${preservation_folder})
    do
        if [[ -z "$last" ]]
        then
            last="1"
        else
            echo "," >> "$identifiers_file"
        fi

        id=$(uuidgen)
        pid="${NA}/${id^^}"
        echo "{
        \"file\": \"${filename}\",
        \"identifiers\": [
          {
            \"identifier\": \"https://hdl.handle.net/${pid}\",
            \"identiferType\": \"URI\"
          },
          {
            \"identifier\": \"${pid}\",
            \"identiferType\": \"hdl\"
          }
        ]
      }" >> "$identifiers_file"
    done

    echo "]" >> "$identifiers_file"
}

# ----------------------------------------------------------------------------------------------------------------------
# Get the item folders and copy them
# From /ARCH12345/master/1
# To /ARCH12345/ARCH12345.1/preservation
# ----------------------------------------------------------------------------------------------------------------------
function move {
    echo "Move ${D}"
    for item in "${D}/master/"*
    do
        item_name=$(basename "$item")
        package="${D}/${ARCHIVE}.${item_name}"
        item_folder="${package}/preservation"
        mkdir -p "$package"
        echo "Move ${item} to ${item_folder}"
        rsync -av -progress "${item}/" "${item_folder}/"
        rename "$package" "$item_name"
        mets "$package" "$item_name"
        identifiers "$package" "$item_name"
    done
}

function main {
    move
}

main

exit 0
