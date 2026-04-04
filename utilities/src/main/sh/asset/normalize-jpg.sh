#!/usr/bin/env zsh
# shellcheck disable=SC2059
### Normalize JPEG image filenames
# This is a utility script to normalize JPEG image filenames
# for convenience of resource folders view-at-a-glance.
#
typeset -r version="0.1"
setopt NULL_GLOB

### --- Standard Output Formatting ---
typeset -r title1="=========================   Normalize JPEG Filenames   ========================="
typeset -r title2="  ------------------  %-36s  ------------------  \n"
typeset -r h1_bar="================================================================================"
typeset -r h2_bar="--------------------------------------------------------------------------------"
typeset -r h3_bar="  ............................................................................  "
typeset  issued_commands

### --- Welcome Message ---
print "$title1"
print "Normalize Renaming JPEG files..."
print "$h1_bar"

fillCalculatedNameData() {
  local -r file_requested=$1
    printf "$title2" "📌 $file ..."
    # Skip if no matching files
    [[ ! -f "$file" ]] && print " ⏭️ Skipping: $file (No such file).\n${h3_bar}\n" && continue

}

processAllFiles() {

  for file in *.jpg *.JPG *.jpeg *.JPEG; do
      printf "$title2" "📌 $file ..."

  #

      # Extract content creation date from metadata
  #    date=$(mdls -raw -name kMDItemContentCreationDate "$file" | sed 's/ /_/g' | cut -d '+' -f1)
  #    date=$(mdls -raw -name kMDItemContentCreationDate "$file" | sed 's/[ :]/-/g' | cut -d '+' -f1)
      date=$(mdls -raw -name kMDItemContentCreationDate "$file" | tr -d ' :')
      desc=$(mdls -raw -name kMDItemFinderComment "$file")
      [[ -z "$desc" || "$desc" == "(null)" ]] && desc=$(mdls -raw -name kMDItemTitle "$file")

      # Ensure date exists
      if [[ -z "$date" || "$date" == "(null)" ]]; then
          printf "💣 %s - %s -> Forced skipping -> (No metadata date found).\n$h3_bar\n\n" "$file" "Creation Date"
          continue
      fi

      base_name="${file%.*}"         # Remove extension
      extension="${file##*.}"        # Get file extension
      extension="${extension:l}"     # Convert extension to lowercase
      base_name="${base_name// /-}"  # Replace spaces with dashes
      base_name="${base_name//_/}"   # Remove underscores (extra handling)
      base_name="${base_name//--/-}" # Replace double dashes with single dash

      # Construct new filename
      newname="${date}${base_name}.${extension}"
      # Skip renaming if the name is already correct
      [[ "$file" == "$newname" ]] && print "👍🏻⏭️ Skipping: $file (Name already correct)\n$h3_bar\n\n" && continue
  #    Saga suggest prompt if we want to rename?
      print "??? Rename: $file -> $newname ??? (Y/n/(o)ther  : "
      read -r -q "response?==> Confirm (y/n)? "
      print

      # shellcheck disable=SC2154
      if [[ "$response" == "y" || "$response" == "Y" ]]; then
          mv "$file" "$newname"
          print "👍🏻 Renamed: $file -> $newname\n$h3_bar\n\n"
      elif [[ "$response" == "o" || "$response" == "O" ]]; then
          read -r -q "🧐 Whoot name?: $file -> $newname\n$h3_bar\n"
      else
          print "👎🏻 Skipped: $file -> $newname\n$h3_bar\n"
      fi

  done
}
print "$h2_bar"

main() {

  processAllFiles
}

main "$@"