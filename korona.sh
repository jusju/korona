#!/bin/bash
# -----------------------------------------------------------
# Checks from app.koronarokotusaika.fi whether people your
# age (without a risk group) are yet eligible for Covid-19
# vaccination or not. Requires curl and jq.
#
# Usage: koronarokotusaika.sh Municipality YearOfBirth
# -----------------------------------------------------------

# CONFIGURATION
CACHE_FILE="/tmp/.koronarokotusaika-cache.json"
CACHE_MAX_SECONDS="600"
API_URL="https://api.koronarokotusaika.fi/api/options/municipalities/"

# Test the inputs...
if (($# != 2));then
  echo "Usage: $0 Municipality YearOfBirth"
  exit 1
fi

if ! [ "$2" -eq "$2" ] 2>/dev/null;then
  echo "Year of birth should be a number!"
  exit 1
fi
MUNICIPALITY=$1
BYEAR=$2
AGE=$(($(date +"%Y")-BYEAR))

# Tests for the requirements...
for cmd in jq curl;do
  if ! command -v "$cmd" &> /dev/null;then
    echo "This script requires $cmd!"
    exit 1
  fi
done

CACHE_TIME=$(stat --format=%Y "$CACHE_FILE" 2>/dev/null)
if ((`date +%s` - ${CACHE_TIME:-0} < CACHE_MAX_SECONDS));then 
  echo "Using data cached @ $(date -Iseconds -d @$CACHE_TIME)"
else
  echo "Downloading fresh data @ $(date -Iseconds)"
  curl -s "$API_URL" -o "$CACHE_FILE"
fi

# Get the data for the municipality...
LABEL=$(jq -c ".[] | select(.label==\"$MUNICIPALITY\")" "$CACHE_FILE")

if [ ! "$LABEL" ];then
  echo "Municipality $MUNICIPALITY not found! Try one of:"
  jq -rc '.[] | .label' "$CACHE_FILE"
  exit 1
fi

# Check the non-risk groups based on the age...
ELIGIBLE_SINCE=$(echo "$LABEL" | jq -c ".vaccinationGroups[] | select((.min<=$AGE) and (.max>=$AGE or .max==null) and (.conditionTextKey==null) and (.startDate!=null)) | \"\(.startDate) (ages \(.min)-\(.max), source \(.source))\"")

if [ "$ELIGIBLE_SINCE" ];then
  echo "Congratulations! People from $MUNICIPALITY born in $BYEAR (turning $AGE this year) have been eligible for Covid-19 vaccination since"
  echo "$ELIGIBLE_SINCE"
else
  echo "Sorry, but people from $MUNICIPALITY born in $BYEAR (turning $AGE this year) are not yet eligible for Covid-19 vaccination! :("
fi
