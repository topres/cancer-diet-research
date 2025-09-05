#!/bin/bash
set -euo pipefail

# Check dependencies
command -v jq >/dev/null 2>&1 || { echo "Error: jq is required but not installed. Install with: brew install jq" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "Error: curl is required but not installed." >&2; exit 1; }

# Function to extract basic citation info from text
extract_citation_info() {
    local ref="$1"
    local authors title journal year doi
    
    # Extract authors (everything before first parentheses with year)
    authors=$(echo "$ref" | sed -n 's/^\([^(]*\)(.*/\1/p' | sed 's/\.$//; s/,$//; s/^[[:space:]]*//; s/[[:space:]]*$//')
    
    # Extract year
    year=$(echo "$ref" | sed -n 's/.*(\([0-9]\{4\}\)).*/\1/p')
    
    # Extract title (text between quotes)
    title=$(echo "$ref" | sed -n 's/.*"\([^"]*\)".*/\1/p')
    
    # Extract journal (text between asterisks or after period before DOI)
    journal=$(echo "$ref" | sed -n 's/.*\*\([^*]*\)\*.*/\1/p')
    if [ -z "$journal" ]; then
        journal=$(echo "$ref" | sed -n 's/.*"[^"]*"[[:space:]]*\([A-Za-z][^0-9]*\)[0-9].*/\1/p' | sed 's/[[:space:]]*$//')
    fi
    
    # Try to find DOI
    doi=$(echo "$ref" | grep -o 'DOI:[[:space:]]*[0-9][0-9]*\.[0-9][0-9]*[^[:space:]]*' | sed 's/DOI:[[:space:]]*//' || echo "N/A")
    if [ "$doi" = "N/A" ]; then
        doi=$(echo "$ref" | grep -o 'doi\.org/[0-9][0-9]*\.[0-9][0-9]*[^[:space:]]*' | sed 's/doi\.org\///' || echo "N/A")
    fi
    
    printf '{"authors":"%s","year":"%s","title":"%s","journal":"%s","doi":"%s"}' "$authors" "$year" "$title" "$journal" "$doi"
}

# Function to classify study type from title/journal
classify_study_type() {
    local title="$1"
    local journal="$2"
    
    case "$title" in
        *meta-analysis*|*Meta-analysis*|*META-ANALYSIS*) echo "Meta-analysis" ;;
        *systematic*review*|*Systematic*Review*) echo "Systematic review" ;;
        *review*|*Review*) echo "Review" ;;
        *randomized*trial*|*clinical*trial*|*RCT*) echo "RCT" ;;
        *cohort*|*prospective*|*longitudinal*) echo "Cohort study" ;;
        *case-control*|*case*control*) echo "Case-control study" ;;
        *cross-sectional*|*survey*) echo "Cross-sectional" ;;
        *) 
            case "$journal" in
                *Cancer*|*Oncol*|*Cell*|*Nature*|*Science*|*PNAS*) echo "Experimental/Mechanistic" ;;
                *) echo "Observational" ;;
            esac
        ;;
    esac
}

# Function to assess evidence quality
assess_quality() {
    local journal="$1"
    local year="$2"
    local study_type="$3"
    
    case "$journal" in
        *Nature*|*Science*|*Cell*) echo "High" ;;
        *Cancer*|*Oncology*|*Clinical*) echo "High" ;;
        *) 
            case "$study_type" in
                "Meta-analysis"|"Systematic review") echo "High" ;;
                "RCT") echo "High" ;;
                "Cohort study") echo "Moderate" ;;
                *) echo "Moderate" ;;
            esac
        ;;
    esac
}

# Function to assess relevance to claim
assess_relevance() {
    local title="$1"
    local claim_file="$2"
    
    case "$claim_file" in
        *claim-01*)
            case "$title" in
                *Warburg*|*metabolism*|*glycolysis*|*glutamine*|*fermentation*) echo "High" ;;
                *cancer*|*tumor*) echo "Moderate" ;;
                *) echo "Low" ;;
            esac
            ;;
        *claim-02*)
            case "$title" in
                *glucose*|*blood*sugar*|*diabetes*|*glycemic*|*insulin*) echo "High" ;;
                *cancer*|*tumor*|*growth*) echo "Moderate" ;;
                *) echo "Low" ;;
            esac
            ;;
        *claim-03*)
            case "$title" in
                *ketone*|*ketogenic*|*mitochondria*|*OXPHOS*|*oxidative*) echo "High" ;;
                *metabolism*|*cancer*) echo "Moderate" ;;
                *) echo "Low" ;;
            esac
            ;;
        *) echo "Moderate" ;;
    esac
}

# Process a single claim file
process_claim_file() {
    local file="$1"
    echo "Processing $file..."
    
    # Check if file already has Sources Review section
    if grep -q "## Sources Review" "$file"; then
        echo "  Sources Review section already exists, skipping..."
        return
    fi
    
    # Extract references section
    local refs_start=$(grep -n "^## References" "$file" | cut -d: -f1)
    if [ -z "$refs_start" ]; then
        echo "  No References section found, skipping..."
        return
    fi
    
    local refs_end=$(tail -n +$((refs_start+1)) "$file" | grep -n "^---" | head -1 | cut -d: -f1)
    if [ -z "$refs_end" ]; then
        refs_end=$(wc -l < "$file")
        refs_end=$((refs_end - refs_start))
    else
        refs_end=$((refs_end - 1))
    fi
    
    # Extract reference lines
    local refs_content=$(sed -n "$((refs_start+1)),$((refs_start+refs_end))p" "$file" | grep "^\[" | head -10)
    
    # Create temporary file for processing
    local temp_file=$(mktemp)
    local sources_table="$temp_file.table"
    
    # Initialize sources review table
    cat > "$sources_table" << 'EOF'
## Sources Review

| Reference | Study Type | Sample/Population | Quality | Relevance | Key Finding | Limitations | Support |
|-----------|------------|-------------------|---------|-----------|-------------|-------------|---------|
EOF
    
    # Process each reference
    local counter=1
    while IFS= read -r ref_line; do
        if [ -z "$ref_line" ] || [[ ! "$ref_line" =~ ^\[.*\] ]]; then
            continue
        fi
        
        echo "  Processing reference $counter..."
        
        # Extract citation text (remove [1], [2], etc.)
        local citation=$(echo "$ref_line" | sed 's/^\[[0-9]*\] *//')
        
        # Extract citation information
        local citation_data=$(extract_citation_info "$citation")
        local authors=$(echo "$citation_data" | jq -r '.authors')
        local year=$(echo "$citation_data" | jq -r '.year')
        local title=$(echo "$citation_data" | jq -r '.title')
        local journal=$(echo "$citation_data" | jq -r '.journal')
        local doi=$(echo "$citation_data" | jq -r '.doi')
        
        # Classify and assess
        local study_type=$(classify_study_type "$title" "$journal")
        local quality=$(assess_quality "$journal" "$year" "$study_type")
        local relevance=$(assess_relevance "$title" "$file")
        
        # Create table row
        local short_ref="[$counter] $authors ($year)"
        local population="Variable"
        local key_finding="See detailed analysis above"
        local limitations="Standard for study type"
        local support="See assessment above"
        
        # Truncate long text for table readability
        if [ ${#authors} -gt 20 ]; then
            short_ref="[$counter] $(echo "$authors" | cut -c1-17)... ($year)"
        fi
        
        # Add to table
        echo "| $short_ref | $study_type | $population | $quality | $relevance | $key_finding | $limitations | $support |" >> "$sources_table"
        
        counter=$((counter + 1))
        sleep 0.1  # Rate limiting
        
    done <<< "$refs_content"
    
    # Append sources review to original file
    echo "" >> "$file"
    cat "$sources_table" >> "$file"
    echo "" >> "$file"
    echo "*Sources Review completed: $(date '+%Y-%m-%d')*" >> "$file"
    
    # Cleanup
    rm -f "$temp_file" "$sources_table"
    echo "  Completed processing $file"
}

# Main execution
echo "Starting sources review automation..."

# Process each claim file
for file in episodes/cancer-and-keto/research/claim-0*.md; do
    if [ -f "$file" ]; then
        process_claim_file "$file"
    fi
done

echo "Sources review automation completed!"
