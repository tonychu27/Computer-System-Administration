#!/bin/sh

# A function to print the usage of this script
print_usage() {
	cat >&2 <<EOF
hw2.sh -p TASK_ID -t TASK_TYPE [-h]

Available Options:

-p: Task id
-t JOIN_NYCU_CSIT|MATH_SOLVER|CRACK_PASSWORD: Task type
-h: Show the script usage
EOF
}

# A function to check the task type
# 1 parameter will be sent to this function
# $TASK_TYPE
validate_task_type() {
	case "$1" in "JOIN_NYCU_CSIT" | "MATH_SOLVER" | "CRACK_PASSWORD")
		return 0
		;;
	*)
		echo "Invalid task type" >&2
		exit 1
		;;
	esac
}

# A function to check task id and task type
# 2 parameters will be sent to this function
# $TASK_ID $TASK_TYPE
check_task_id() {
	TASK_ID=$1
	TASK_TYPE=$2

	URL="http://10.113.0.253/tasks/$TASK_ID"
	GET_RES=$(curl -s "$URL" -H "Content-Type: application/json")
	TYPE=$(echo "$GET_RES" | jq -r '.type')
	STATUS=$(echo "$GET_RES" | jq -r '.status')

	if [ "$STATUS" = "null" ]; then
		echo "Invalid task not match" >&2
		exit 1
	fi

	if [ "$TYPE" != "$TASK_TYPE" ]; then
		echo "Task type not match" >&2
		exit 1
	fi
}

# A function for verifying my answer
# 1 parameter will be sent to this function
# $TASK_ID
check_response() {
	TASK_ID=$1
	GET_URL="http://10.113.0.253/tasks/$TASK_ID"
	GET_RES=$(curl -s "$GET_URL" -H "Content-Type: application/json")
}

# A function to send answer
# 2 parameters will be sent to this function
# $TASK_ID, $ANS
send() {
	TASK_ID=$1
	ANS=$2
	URL="http://10.113.0.253/tasks/$TASK_ID/submit"
	curl -s -X POST "$URL" -H "Content-Type: application/json" -d "$ANS"
}

# A function to solve JOIN_NYCU_CSIT problem
# 1 parameter will be sent to this function
# $TASK_ID
nycu() {
	
	TASK_ID=$1
	ANS=$(jq -n --arg answer "I Love NYCU CSIT" '{answer: $answer}')
	
	send "$TASK_ID" "$ANS"
}

# A function to solve math problem
# 2 parameters will be sent to this function
# $TASK_ID, $RESPONSE
solve_math() {
	
	TASK_ID=$1
	URL="http://10.113.0.253/tasks/$TASK_ID"
	RESPONSE=$(curl -s "$URL" -H "Content-Type: application/json")

	PROBLEM=$(echo "$RESPONSE" | jq -r '.problem')
	a=$(echo "$PROBLEM" | awk '{print $1}')
	op=$(echo "$PROBLEM" | awk '{print $2}')
	b=$(echo "$PROBLEM" | awk '{print $3}')
	
	if [ "$a" -lt -10000 ] || [ "$a" -gt 10000 ] || [ "$b" -lt 0 ] || [ "$b" -gt 10000 ]; then
        	answer="Invalid problem"	
	else
		case "$op" in
			"+")
				answer=$((a + b))
				;;
			"-")
				answer=$((a - b))
				;;
			*)
				answer="Invalid problem"
				;;
		esac
	fi

	ANS=$(jq -n --arg answer "$answer" '{"answer": $answer}')

	send "$TASK_ID" "$ANS"
}

# A function to check the decoded string
# 1 parameter will be sent to this function
# $DECODE
validate_decode() {
	decode="$1"
	if echo "$decode" | grep -qE '^NYCUNASA\{[A-Za-z]{16}\}$'; then
		return 0
	else
		return 1
	fi
}

# A function to shift character
# 3 parameters will be sent to this function
# $CHAR, $SHIFT_AMOUNT, $DIRECTION
shift_char() {
    char="$1"
    shift_amount="$2"
    direction="$3"
    
    if echo "$char" | grep -q "[A-Za-z]"; then
        ascii=$(printf "%d" "'$char")
        
        if echo "$char" | grep -q "[A-Z]"; then
            base=65
        else
            base=97
        fi
        
        if [ "$direction" = "left" ]; then
            new_ascii=$(( (ascii - base - shift_amount + 26) % 26 + base ))
        else
            new_ascii=$(( (ascii - base + shift_amount) % 26 + base ))
        fi
    	awk -v ascii="$new_ascii" 'BEGIN { print sprintf("%c", ascii) }'	
    else
        printf "%s" "$char"
    fi
}

# A function to decode the string
# 3 parameters will be sent to this function
# $SHIFT_AMOUNT, $DIRECTION, $ENCRYPTED
decode_string() {
    shift_amount="$1"
    direction="$2"
    encrypted="$3"

    decoded=""
    i=0
    while [ $i -lt ${#encrypted} ]; do
        char=$(printf "%s" "$encrypted" | cut -c $((i + 1)))
        decoded=$decoded$(shift_char "$char" "$shift_amount" "$direction")
        i=$((i + 1))
    done
    
    echo "$decoded"
}

# A function to solve crack password problem
# 1 parameter will be sent to this function
# $TASK_ID
crack() {
	TASK_ID=$1
	URL="http://10.113.0.253/tasks/$TASK_ID"
	RESPONSE=$(curl -s "$URL" -H "Content-Type: application/json")
	PROBLEM=$(echo "$RESPONSE" | jq -r '.problem')
	FLAG=0
	
	shift=1
	while [ $shift -le 13 ]; do
		RES=$(decode_string $shift "left" "$PROBLEM")
		if validate_decode "$RES"; then
			FLAG=1
			ANS=$(jq -n --arg answer "$RES" '{"answer": $answer}')
			break	
		fi
		RES=$(decode_string $shift "right" "$PROBLEM")
		if validate_decode "$RES"; then
			FLAG=1
			ANS=$(jq -n --arg answer "$RES" '{"answer": $answer}')
			break
		fi
    		shift=$((shift + 1))
	done

	if [ "$FLAG" -eq 0 ]; then
		ANSWER="Invalid problem"
		ANS=$(jq -n --arg answer "$ANSWER" '{"answer": $answer}')
	fi

	send "$TASK_ID" "$ANS"

}

# Main Function
while getopts ":p:t:h" opt; do
	case $opt in
		p)
			TASK_ID=$OPTARG
			;;
		t)
			TASK_TYPE=$OPTARG
			;;
		h)
			print_usage
			exit 0
			;;
		\?)
			print_usage
			exit 1
			;;
		:)
			print_usage
			exit 1
			;;
	esac
done

if [ -z "$TASK_ID" ] || [ -z "$TASK_TYPE" ]; then
	echo "Missing required arguments" >&2
	print_usage
	exit 1
fi

validate_task_type "$TASK_TYPE"

check_task_id "$TASK_ID" "$TASK_TYPE"

if [ "$TASK_TYPE" = "JOIN_NYCU_CSIT" ]; then
	nycu "$TASK_ID"
elif [ "$TASK_TYPE" = "MATH_SOLVER" ]; then
	solve_math "$TASK_ID"
elif [ "$TASK_TYPE" = "CRACK_PASSWORD" ]; then
	crack "$TASK_ID"
else
	echo "Invalid task type" >&2
	exit 1
fi