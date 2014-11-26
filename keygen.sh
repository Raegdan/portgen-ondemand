#!/bin/bash

usage() {
	echo "Usage:"
	echo "keygen.sh action"
	echo
	echo "Actions:"
	echo "    c | change <key>  : regenerate existing key"
	echo "    a | add <key>     : add a new key"
	echo "    d | delete <key>  : delete a key"
	echo
	exit 0
}

askYN() {
	while [[ true ]]; do
		echo -n $@
		read r

		case "$r" in
			"y" | "Y" )
				return 0
			;;
			
			"n" | "N" )
				return 1
			;;
		esac	
	done
}

fail() {
	echo $@
	exit 1
}

ts () {
	date -u "+[%Y-%m-%d %H:%M:%S UTC]"
}

cd $( dirname $0 )

case "$1" in
	"c" | "change")
		if [[ -f "$2".key ]]; then

			askYN "Regenerate and deploy key \"$2\" -- sure? (y/n) :"
			if [[ $? != 0 ]]; then fail "Aborted by user"; fi				
			
			KEYSIZE=$(( ( $( du -sb "$2".key | cut -d\t -f1 ) - 1 ) / 2 ))
			askYN "Current \"$2\" length is $KEYSIZE bytes -- change? (y/n) :"
			if [[ $? == 0 ]]; then
				while [[ true ]]; do
					echo -n "New length? : "
					read NEW_KS
					case $NEW_KS in
						''|*[!0-9]*) 
							continue
						;;
						
						*)
							break
						;;
					esac
				done
				KEYSIZE=$NEW_KS
				echo "Length of \"$2\" changed to $KEYSIZE bytes."
			fi
			
			NEWKEY=$( dd if=/dev/random bs=1 count=$KEYSIZE 2>/dev/null | xxd -p -c 100500 )
			echo "New \"$2\" value: $NEWKEY"
			echo "$NEWKEY" > "$2".key
			echo "Key file written."
			echo "$( ts ) $2 changed: size $KEYSIZE value $NEWKEY" >> "$2".history
			echo "History written."
			git add "$2".key "$2".history
			echo "$( ts ) $2 changed" | git commit -F -
			git push
			echo "Deployed to Git."
		else
			echo Key "$2" does not exist!
			echo
			usage
		fi
	;;

	"a" | "add")
		if [[ -f "$2".key ]]; then
			echo Key "$2" already exists!
			echo
			usage
		fi	
		
		if [[ $2 == "" ]]; then
			echo Key name is missing.
			echo
			usage
		fi
		
		askYN "Generate and deploy a new key \"$2\" -- sure? (y/n) :"
		if [[ $? != 0 ]]; then fail "Aborted by user"; fi				
		
		while [[ true ]]; do
			echo -n "Choose key length, bytes : "
			read KEYSIZE
			case $KEYSIZE in
				''|*[!0-9]*) 
					continue
				;;
				
				*)
					break
				;;
			esac
		done
		
		NEWKEY=$( dd if=/dev/random bs=1 count=$KEYSIZE 2>/dev/null | xxd -p -c 100500 )
		echo "Generated \"$2\" value: $NEWKEY"
		echo "$NEWKEY" > "$2".key
		echo "Key file written."
		echo "$( ts ) $2 generated: size $KEYSIZE value $NEWKEY" >> "$2".history
		echo "History written."
		git add "$2".key "$2".history
		echo "$( ts ) $2 generated" | git commit -F -
		git push
		echo "Deployed to Git."		
	;;
	
	"d" | "delete")
		if [[ -f "$2".key ]]; then
			echo "You are trying to delete the key \"$2\""
			echo ">>> WARNING: KEY DELETION WHILE IN USE MAY LEAD TO INACCESSIBLE SERVICES!!! <<<"
			echo "Think twice before doing so, and type I AM SURE if you still want to proceed."
			echo -n "> "
			read x
			if [[ $x != "I AM SURE" ]]; then
				fail "You are not sure."
			fi
			
			git rm -f "$2".key "$2".history
			echo "Deleted."
			echo "$( ts ) $2 deleted" | git commit -F -
			git push
			echo "Deployed to Git." 
						
		else
			echo Key "$2" does not exist!
			echo
			usage
		fi
	;;
	* )
		usage
	;;
esac

echo "Finished!"
