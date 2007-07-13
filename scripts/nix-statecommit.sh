#! /bin/sh
# we cant do a -e since ... svn can fail ??? TODO...

#check if there are enough arguments, if not, exit with an error

debug="";		#set to "" for no debugging, set to "echo " to debug the commands

if [ "$#" != 6 ] && [ "$#" != 7 ] ; then
  echo "Incorrect number of arguments"
  exit 1;
fi

if [ "$deletesvn" != "" ] && [ "$deletesvn" != "1" ]; then
  echo "The last argument (DELETE svn folders) must be either empty (recommended) or 1"
  exit 1;
fi

svnbin=$1
subversionedpaths=( $2 )				#arrays
subversionedpathsCommitBools=( $3 )
nonversionedpaths=( $4 )
checkout=$5
statepath=$6
deletesvn=$7							#this flag can be set to 1 to DELETE all .svn folders and NOT commit


if [ "$debug" != "" ] ; then
	echo svnbin: $svnbin
	echo subversionedpaths: ${subversionedpaths[@]}
	echo subversionedpathsCommitBools: ${subversionedpathsCommitBools[@]}
	echo nonversionedpaths: ${nonversionedpaths[@]}
	echo checkouts: $checkout
	echo statepath: $statepath
	echo deletesvn: $deletesvn
fi

#
#
#
#
function subversionSingleStateDir {

	  excludelist=( "." ".." ".svn" );

      checkForSVNDelete $1;													#check for deleted files/folders (TODO does this also need to be here ???)

	  cd $1;
	  #echo cd $1;
	  
	  empty=$(ls)
	  
	  if [ "$empty" = "" ] ; then
	  	allsubitems=();														#no subfiles / dirs
	  else
	  	allsubitems=( $(echo *) $(echo .*) )								#there are subfiles / dirs,also adds hidden items
	  fi

	  for subitem in ${allsubitems[@]}
	  do
	  	  if [ "$subitem" = ".svn" ]; then
	  	  		allsubitems=( $($svnbin -N stat | sed -n '/^?/p' | sed 's/?     //' | tr -d "\12") )		#there are subfiles, and theyre already versioned
	  	  		
	  	  		if [ "$deletesvn" = "1" ]; then
	  	  		  rm -rf .svn/
	  	  		fi
	  	  fi
	  done
	  
	  #echo "Allsubitems ${allsubitems[@]}"
	  																		
	  subitems=();
	  for subitem in ${allsubitems[@]}										#add all, were going to exlucde explicity stated direct versioned-subdirs or explicity stated nonversioned-subdirs
	     do																	#this is only to prevent some warnings, ultimately we would like svn add to have a option 'exclude dirs'

		  exclude=0;
		  
	  	  for excl in ${excludelist[@]}										#check if the subitem is in the list of excluded dirs
		  do
		  	  if [ "$excl" = "$subitem" ]; then
		  	    exclude=1;
		  	    #echo "exclude $excl"
		  	  fi
		  done	  	  

		  subitem="$(pwd)/$subitem";										#create the full path
		  
		  if test -d $subitem; then											#the subitem (file or a dir) may be a dir, so we add a / to the end
		  	subitem="$subitem/";
		  fi
		  
		  for svnp in ${subversionedpaths[@]}								#check if the subitem is in the list of subverioned paths
		  do
		  	  if [ "$svnp" = "$subitem" ]; then
		  	    exclude=1;
		  	    #echo "exclude versioned $svnp"
		  	  fi
		  done
		
		  for nonvp in ${nonversionedpaths[@]}								#check if the subitem is in the list of dirs that aren't supposed to be versioned
		  do	
		  	  if [ "$nonvp" = "$subitem" ]; then
		  	    exclude=1;
		  	    #echo "exclude nonversioned $svnp"
		  	  fi
		  done
		  
		 if [ $exclude = 0 ]; then											#Exclude the subitem if nessecary
            subitems[${#subitems[*]}]=$subitem
         fi
      done  
	  
	  #echo ${subitems[@]}
	  
	  for item in ${subitems[@]}
	     do
	     if test -d $item; then												#add or go recursive subitems
		     if [ "$deletesvn" != "1" ]; then
		     	$debug $svnbin -N add $item									#NON recursively add the dir
		     fi
		     subversionSingleStateDir $item
		 else
		     if [ "$deletesvn" != "1" ]; then
		 	 	$debug $svnbin add $item
		 	 fi
		 fi
	  done

}  

#
# Takes a dir or file, checks for deleted files / folders and svn delete's them
#

function checkForSVNDelete {

	#echo checking for deleted items: $1;
	allsubitems=( $($svnbin -N stat $1 | sed -n '/^!/p' | sed 's/!     //' | tr -d "\12") )		#select all deleted files
	#echo "All deleted subitems ${allsubitems[@]}"
	
	for subitem in ${allsubitems[@]}															#then svn delete them
	do	
		$debug $svnbin delete $subitem
	done
}

#
#
#
#

if ! test -d "${statepath}/.svn/"; then       									#if the root dir exists but is not yet an svn dir: checkout repos, if it doenst exits (is removed or something) than we dont do anything
	if [ "$deletesvn" != "1" ]; then											#TODO !!!!!!!!!!!!!!! we shouldnt checkout !!!!!!!!!!!!!!!!!
		$debug $checkout;
	fi
fi

i=0
for path in ${subversionedpaths[@]}
do
   
   checkForSVNDelete $path;														#check if path or file is deleted
   
   if test -d $path; then														#if the dir doesnt exist, than we dont hav to do anything
      cd $path;
	  																		    
      if [ "${subversionedpathsCommitBools[$i]}" = "true" ]; then				#Check if we need to commit this folder
          echo "Entering $path"
		  
		  if ! test -d "${path}/.svn/"; then									#Dir: Also add yourself if nessecary
		  	  if [ "$deletesvn" != "1" ]; then									
				$debug $svnbin -N add $path										
			  fi
		  fi
		  
		  subversionSingleStateDir $path;
	  fi
      
      cd - &> /dev/null;
      let "i+=1"
   fi

   if test -f $path; then														#if its a file, see if it needs to be added
	   
	   if [ "${subversionedpathsCommitBools[$i]}" = "true" ]; then				#Check if we need to commit this file
	   
		   alreadyversioned=$(svn -N stat $path )
		   if [ "$alreadyversioned" != "" ]; then
  			    echo "Subversioning $path"
		   		$debug $svnbin add $path	
		   fi
	   fi
   fi
   
done

cd $statepath																	#now that everything is added we go back to the 'root' path and commit
if [ "$deletesvn" != "1" ]; then
	$debug $svnbin -m "" commit;
	$debug $svnbin up "" commit;												#do a svn up to update the local revision number ... (the contents stays the same)
fi
