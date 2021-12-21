#! /bin/bash

#vsh

#Script coté client, il engagera la connexion avec le serveur


#On déclare les variables globales générales à toutes les commandes
declare -r mode=$1
declare -r NOM_SERV=$2
declare -r PORT=$3
declare -r ARCHIVE=$4


if [[ -z $NOM_SERV || -z $PORT ]];then
	echo "Veuillez rentrer un nom de serveur et un port"

else
	if [ "$mode" = "-create" ];then

		if [ -z $4 ];then
			echo "Veuillez indiquer le nom de l'archive à créer"
			echo "Usage: vsh -create [NOM_SERVEUR] [PORT] [NOM_ARCHIVE]"
		else


		ls -Rl > listeFich #Le fichier listeFich est le fichier sur lequel on boucle pour afficher l'archive
			echo "Directory: $(pwd)" >> temp_header # on initialise la première ligne de notre header avant la boucle
			j=0
			bodydeb=1 #variable qui sert à repérer le début du fichier dans le body
			taille=0 
			nomDirectory=()
			current=$(pwd) #variable qui nous sert à nous repérer dans l'arborescence 
			while read ligne 
			do

				set -- $ligne #facilite la manipulation

				if [ "$9" != "$ARCHIVE" -a  "$9" != "listeFich" -a "$9" != "" ]; then #On vérifie si la ligne correspond bien à une ligne à afficher (ligne d'un fichier ou d'un répertoire)
						if [ ! -d $current/$9 ]; then
							if [ -r $current/$9 ]; then #si le fichier est lisible on le met dans le fichier temporaire du body
								cat $current/$9 >> temp_body #on enregistre le contenu du fichier dans le body
								if [ "$taille" -ne 0 ]; then #si sa taille du fichier précédent est != de 0 alors on incrémente la variable bodydeb
								bodydeb=$(echo $(($bodydeb+$taille)))
								fi
								taille=$(wc -l $current/$9 | cut -f1 -d' ') #on calcule la taille du fichier actuel
								if [ $taille -eq 0 ];then
									echo "$9 $1 $5 $bodydeb" >> temp_header #si il est vide (taille=0) on affiche pas l'information
								else 
									echo "$9 $1 $5 $bodydeb $taille" >> temp_header 
								fi
							fi
						else 
							echo "$9 $1 $5" >> temp_header
						fi	
				fi
				if [[ $ligne =~ ^\./.+:$ ]]; then #si on repère un ligne de changement de dossier dans le ls -Rl
					((j++))
					nomDirectory[$j]=$(echo $ligne | cut -f2 -d'.' | sed 's/://') #on récupère le nom de se dossier
					echo "@" >> temp_header #marquage de changement de dossier
					echo "Directory: $(pwd)${nomDirectory[$j]}" >> temp_header #donc on affiche le nom du répertoire et son fullpath
					current=$(pwd)${nomDirectory[$j]} #on actualise le dossier dans lequel on se trouve ce qui va permettre de cat les fichiers de se dossier
				fi

			done < "listeFich" #On effectue la boucle sur le ls -Rl

			rm listeFich	
			debut_header=3
			taille_body=$(wc -l temp_header | cut -f1 -d' ')
			debut_body=$(echo $(($taille_body+$debut_header+1)))

			echo "$debut_header:$debut_body" > $ARCHIVE
			echo "" >> $ARCHIVE
			sed -i 's/\//\\/g' temp_header #on remplace tous les '/' par des '\'
			cat temp_header >> $ARCHIVE
			echo "FIN DU HEEEAAADDEEERRRR" >> $ARCHIVE
			cat temp_body >> $ARCHIVE
		echo ${mode:1} $ARCHIVE $(cat temp_header) | nc -w1 $NOM_SERV $PORT
			rm temp_body
			rm temp_header
		fi
	elif [ "$mode" = "-list" ];then
		echo ${mode:1} | nc -w1 $NOM_SERV $PORT


	elif [ "$mode" = "-extract" ];then
		if [ -z $4 ];then
			echo "Veuillez indiquer l'archive à extraire"
			echo "Usage: vsh -extract [NOM_SERVEUR] [PORT] [NOM_ARCHIVE]"
		else

			repCourant=$(pwd)
			echo $repCourant
			cd archive
			pwd

			sed 's/\\/\//g' $ARCHIVE > tempArch
			cp tempArch ../tempArch
			firstLine=$(head -1 tempArch) #Je prends separemment la premiere ligne pour avoir le debut du header et du body
			debut_header=$(echo $firstLine | cut -d':' -f1) 
			debut_body=$(echo $firstLine | cut -d':' -f2)		

			i=0
			while read ligne #On va verifier si le fichier dans tempArch est un dossier ou pas
			do
				((i++))
				if [[ $i -eq $debut_body ]];then #On analyse que le header, si on arrive à la ligne du body on sort de la boucle
					break		
				fi
				set -- $ligne

					if [[ $ligne =~ ^"Directory"+ ]];then #Si c'est un directory alors on créé le dossier chez le client
						mkdir -p $repCourant/$2
						cd $repCourant/$2
						#echo "je suis dans le directory $2"

						j=0
						while read line #Pour chaque dossier je créé les fichiers dedans
						do
							((j++))
							echo "j est egal à $j"
							set -- $line
							if [[ "$line" = "@" ]] || [[ $j -eq $debut_body ]];then #Quand on change de dossier ou qu'on arrive au body on sort de la boucle
								break
							else
								#echo " C'est la ligne $line"
								if [[ $(echo $2 | cut -c1) = "d" ]];then  #Si dans le dossier on a encore un dossier on le crée sinon on créé un fichier vide 
									mkdir $1
								elif [[ $(echo $2 | cut -c1) = "-" ]];then
									touch $1
									for (( iter=$4+$debut_body; iter<=$4+$debut_body+$5-1; iter++ ))  #On mets ce qu'il y'a de la ligne indiquée dans le header jusqu'à la taille du fichier
									do
										
										head -n $(( $4+$debut_body+$5 - 2 )) ~/projet/tempArch | tail -n $(( $5 ))  > $1

									done
								
								fi
							fi


						done
						
					elif [[ $ligne =~ ^[^@+] ]] && [ "$4" != "" ];then
						echo ""
						#echo "c'est la ligne $1" 
					fi
					
			done < tempArch
			cd
			cd projet/archive
			rm tempArch
			

		
		
			echo ${mode:1} $ARCHIVE | nc -w1 $NOM_SERV $PORT
		
		fi



	fi
	
fi

