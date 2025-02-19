#!/bin/bash

# CONFIGURAÇÕES
ROOTDIR="$HOME/blog";
WEBSITE_NAME='Saindo da Falha';
WEBSITE_TAB='Saindo da Falha';
WEBSITE_AUTOR='Saindo da Falha';
VERSION='';
RAW_EDITOR='vim';

# estrutura do diretório do SDFC
LAYDIR="$ROOTDIR/lay"; # layouts (*.html)
MODDIR="$ROOTDIR/mod"; # módulos (*.html)
CSSDIR="$ROOTDIR/css"; # css     (*.css)
RSSDIR="$ROOTDIR/rss"; # rss     (*.xml)
VARDIR="$ROOTDIR/var"; # var     (*.txt)
RAWDIR="$ROOTDIR/raw"; # raw     (*.txt)
WWWDIR="$ROOTDIR/docs"; # www     directories

# estrutura do diretório do site
WEBSITE_URL='';
WEBSITE_ROOT="$WWWDIR";
WEBSITE_HOME="$WEBSITE_ROOT";
WEBSITE_FILES="$WEBSITE_HOME/files";
WEBSITE_PAGES="$WEBSITE_HOME/r";
LAYOUT="$LAYDIR/layout.html";

# configurações de RSS
WEBSITE_URL_RSS='https://saindodafalha.github.io/blog';
RSS_TEMPLATE="$RSSDIR/rss.xml";
RSS_DESC="RSS feed do Saindo da Falha.";
RSS_LIST="$VARDIR/rss-all.txt";
RSS_LINK_BASE='https://saindodafalha.github.io/blog/r/'
RSS_ITEM_TEMPLATE='@RAW-DATE@ <item><title>@TITLE@</title><description>@DESC@</description><link>@LINK@</link><pubDate>@DATE@</pubDate></item>';

# configurações de CSS
CSS_TO_COMPILE='main.css html-comment-box.css mobile.css';
CSS_ROOT_THEME='root-minimal.css';


# FUNÇÕES
msg() {
   local msg="$1";
   echo "SDFC: $msg";
}

warn() {
   local msg="$1";
   echo "SDFC: Aviso: $msg";
}

err() {
   local msg="$1";
   echo "SDFC: Erro: $msg";
   exit 1;
}

ensureDir() {
   local dir="$1";
   [[ -d "$dir" ]] || mkdir -p "$dir";
}

checkRawIsSigned() {
   local raw="$1";
   grep '<!--ARTICLE-IS-SIGNED-->' "$RAWDIR/${raw}.txt" > /dev/null && return 0 || return 1;
}

checkRawExists() {
   local raw="$1";
   [[ -f "$RAWDIR/${raw}.txt" ]] && return 0 || return 1; 
}

createRaw() {
   local raw="$1";   
   checkRawExists "$raw" && err 'Não foi criado porque já existe.';
   touch "$RAWDIR/${raw}.txt";
}

writeRaw() {
   local raw="$1";   
   checkRawExists "$raw" || err 'Esse arquivo não existe.';
   checkRawIsSigned "$raw" && err 'Esse arquivo já foi assinado.';
   # abre no editor
   "$RAW_EDITOR" "$RAWDIR/${raw}.txt"; 
}

editRaw() {
   local raw="$1";   
   checkRawExists "$raw" || err 'Esse arquivo não existe.';
   checkRawIsSigned "$raw" || err 'Esse arquivo não está assinado.';
   # aviso
   warn 'Você está editando um arquivo já assinado.';
   # edit on EDITOR
   "$RAW_EDITOR" "$RAWDIR/${raw}.txt"; 
}

extractRawNameFromPath() {
   local raw_path="$1";
   local raw="$(basename "$raw_path")";
   raw="${raw/raw-/}";
   raw="${raw/.txt/}";
   echo -n "$raw";
}

listRaws() {
   local raws=("$(ls $RAWDIR/*)"); 
   local list='';
   for raw_path in ${raws[@]}
   do
      local raw="$(extractRawNameFromPath "$raw_path")";
      if checkRawIsSigned "$raw" 
      then
         title="$(getRawMeta "$raw" --title)";
         sign_date="$(getRawMeta "$raw" --date-signed)";
         sign_date="$(date -d @$sign_date '+%d/%m/%Y')";
         last_date="$(getRawMeta "$raw" --date-updated)";
         [[ $last_date == 'NEVER' ]] || last_date="$(date -d @$last_date '+%d/%m/%Y')";
         
         list="${list}$(echo "RAW: $raw \t SIGNED: $sign_date \t UPDATED: $last_date \t TITLE: " | column -t -l 7) $title \n";
      else
         list="$list""DRAFT: $raw\n";
      fi
   done
   # saída
   echo -e "$list" | sed '/^$/d' | sort -r; 
}

listUnsignedRaws() {
      listRaws | grep '^DRAFT: ';
}

signRaw() {
   local raw="$1";
   checkRawExists "$raw" || err 'Esse arquivo não existe.';
   checkRawIsSigned "$raw" && err 'Esse arquivo já está assinado.';
   local timestamp="$(date '+%s')";
   read -p 'Article title: ' article_title;
   read -p 'Cover (ENTER: 📄): ' cover;
   [[ -n "$cover" ]] || cover='📄';
   echo -e "Opções são: \n\nunlisted\tNÃO listar na lista principal\nno-rss\t\tNÃO criar entrada RSS.\nno-comments\tDesativar comentários.\nhidden\t\tNão ser listado automáticamente em nenhuma lista.\n\nSeparar por espaços.\n";
   read -p 'Opções (ENTER: defaults): ' options;
   [[ -n "$options" ]] || options='defaults';
   # tags
   echo -e "\nSeparar tags por espaços.";
   read -p 'Tags (ENTER: none): ' tags;
   [[ -n "$tags" ]] || tags='none';
   # cria o sha256
   local hash="$(sha256sum "$RAWDIR/${raw}.txt" | cut -d' ' -f1)"; 
   # cria o nicedate
   local nicedate="no-nice-date";
   echo -ne "\n";
   read -p 'Usar nice-date (y)? ';
   if [[ "$REPLY" == 'y' ]] 
   then
         nicedate_string="$(niceDate "$timestamp")";
         echo -e "\nString do nice-date é: \n$nicedate_string\n";
         read -p 'Usar (y)? Ou cancelar? ';
         [[ "$REPLY" == 'y' ]] && nicedate="$nicedate_string";
   fi
   # sign               ^ title            ^ signed date  ^ cover    ^ upt ^ opções     ^ hash    ^ nicedate    ^ tags    ^
   local signature='<!--^'"$article_title"'^'"$timestamp"'^'"$cover"'^NEVER^'"$options"'^'"$hash"'^'"$nicedate"'^'"$tags"'^-->';
   echo -e "<!--ARTICLE-IS-SIGNED-->" "\n$signature" >> "$RAWDIR/${raw}.txt";
}

getRawMeta() {
   local raw="$1";
   local field="$2";
   checkRawExists "$raw" || err 'Esse arquivo não existe.';
   checkRawIsSigned "$raw" || err 'Esse arquivo não está assinado.';
   # retorna um metadado de um raw
   local meta="$(tail -n 1 "$RAWDIR/${raw}.txt")";
   case "$field" in
      --title)          echo "$meta" | cut -d^ -f2 ;;
      --date-signed)    echo "$meta" | cut -d^ -f3 ;;
      --cover)          echo "$meta" | cut -d^ -f4 ;;
      --date-updated)   echo "$meta" | cut -d^ -f5 ;;
      --options)        echo "$meta" | cut -d^ -f6 ;;
      --hash)           echo "$meta" | cut -d^ -f7 ;;
      --nice-date)      echo "$meta" | cut -d^ -f8 ;;
      --tags)           echo "$meta" | cut -d^ -f9 ;;
      *)                err "Metadado inexistente.";;
   esac
}

updateRawSignature() {
   local raw="$1";
   local yes="$2";
   checkRawExists "$raw" || err 'Esse arquivo não existe.';
   checkRawIsSigned "$raw" || err 'Esse arquivo não está assinado.';
   # carrega a assinatura antiga
   local raw_path="$RAWDIR/${raw}.txt"; 
   local sig="$(tail -n 1 "$raw_path")";
   local last_date="$(getRawMeta "$raw" --date-updated)";
   local now="$(date '+%s')";
   local old_hash="$(getRawMeta "$raw" --hash)";
   # cria o novo sha256, ignorando as assinaturas
   signature_line_number="$(grep -n '<!--ARTICLE-IS-SIGNED-->' "$raw_path" | cut -d: -f1)";
   content_without_signature="$(head -n $(($signature_line_number - 1)) "$raw_path")";
   new_hash="$(echo "$content_without_signature" | sha256sum | cut -d' ' -f1)";
   # substitui na assinatura
   sig="${sig/$last_date/$now}";
   sig="${sig/$old_hash/$new_hash}";
   # atualiza a assinatura
   if [[ "$yes" == '-y' ]]; then
      echo -e "$sig" >> "$raw_path";
      exit 0;
   fi
   read -p 'Confirmar (y)? '
   [[ "$REPLY" == 'y' ]] && echo -e "$sig" >> "$raw_path";
}

genPostsList() {
   ls $RAWDIR/*.txt &> /dev/null || err "Não há raws.";
   local posts="$(ls $RAWDIR/*.txt)"; 
   local posts_list='';  
   for post_path in ${posts[@]}
   do
      local post="$(extractRawNameFromPath "$post_path")";
      checkRawIsSigned "$post" || continue;

      # filter out if name is not only integers 
      grep -q -E '^[0-9]*$' <<< "$post" || continue;  

      local title="$(getRawMeta "$post" --title)";
      local unix_date="$(getRawMeta "$post" --date-signed)";
      local cover="$(getRawMeta "$post" --cover)";
      local options="$(getRawMeta "$post" --options)";
      local hash="$(getRawMeta "$post" --hash)";
      local date="$(date -d @"$unix_date" '+%d/%m/%Y')";
      #list_item="<li><a href='./r/$post/index.html'><span class='emoji-cover'>$cover</span><span><div>$title</div><div class='color-weak' style='font-weight:normal'>$date</div></span></a></li>\n";
      list_item="<!-- "$unix_date" --> <li><a href='./r/$post/index.html'><span>$cover</span>&nbsp;<span class='color-weak' style='font-weight:normal'>$date</span>&nbsp;-&nbsp;<span>$title</span></a></li>\n";
      # checa opções
      if grep 'unlisted' <<< "$options" &> /dev/null;
      then
         list_item='';
      fi
      posts_list="$posts_list$list_item";
   done
   # saída
   echo -e "$posts_list" | tac | sed '/^$/d';
}

genCompactPostsList() {
   local prefix="$1";
   local allow_main="$2";
   ls $RAWDIR/*.txt &> /dev/null || err "Não há raws.";
   local posts="$(ls $RAWDIR/*.txt)"; 

   local posts_list='';  
   for post_path in ${posts[@]}
   do
      local post="$(extractRawNameFromPath "$post_path")";
      checkRawIsSigned "$post" || continue;

      # filter main posts (named integers only) out 
      # dont filter if --allow-main
      if [[ "$allow_main" != '--allow-main' ]]; then
        grep -q -E '^[0-9]*$' <<< "$post" && continue;  
      fi

      # filter only posts which filename begins with $prefix 
      grep -q "^${prefix}.*$" <<< "$post" || continue; 

      local title="$(getRawMeta "$post" --title)";
      local unix_date="$(getRawMeta "$post" --date-signed)";
      local cover="$(getRawMeta "$post" --cover)";
      local options="$(getRawMeta "$post" --options)";
      local hash="$(getRawMeta "$post" --hash)";
      local date="$(date -d @"$unix_date" '+%d/%m/%Y')";
      list_item="<!-- "$unix_date" --> <li><a href='./r/$post/index.html'><span>$cover</span>&nbsp;<span class='color-weak' style='font-weight:normal'>$date</span>&nbsp;-&nbsp;<span>$title</span></a></li>\n";

      # checa opções
      if grep -q 'hidden' <<< "$options";
      then
         list_item='';
      fi
      posts_list="$posts_list$list_item";
   done
   # saída
   # warn: sorting was untested but i guess it werks
   echo -e "$posts_list" | sort -r -n -k 2 | sed '/^$/d';
}

parseToHTML() {
   # conteúdo do raw
   local raw="$1"; 
   # display block
   raw="$(echo "$raw" | sed -e 's/^\([^;;].*$\)/<p>\1<\/p>/g')";     # <p> default 
   raw="$(echo "$raw" | sed -e '/^$/d')";                            # remove linhas vazias
   raw="$(echo "$raw" | sed -e 's/^;p \(.*$\)/<p>\1<\/p>/g')";       # <p>
   raw="$(echo "$raw" | sed -e 's/^;H \(.*$\)/<h2>\1<\/h2>/g')";    # <h2>
   raw="$(echo "$raw" | sed -e 's/^;h \(.*$\)/<h3>\1<\/h3>/g')";    # <h2>
   raw="$(echo "$raw" | sed -e 's/^;h2 \(.*$\)/<h2>\1<\/h2>/g')";    # <h2>
   raw="$(echo "$raw" | sed -e 's/^;h3 \(.*$\)/<h3>\1<\/h3>/g')";    # <h3>
   raw="$(echo "$raw" | sed -e 's/^;h4 \(.*$\)/<h4>\1<\/h4>/g')";    # <h4>
   raw="$(echo "$raw" | sed -e 's/^;bq \(.*$\)/<blockquote>\1<\/blockquote>/g')";    # <blockquote>
   raw="$(echo "$raw" | sed -e 's/^;li \(.*$\)/<li>\1<\/li>/g')";    # <li>
   raw="$(echo "$raw" | sed -e 's/^;C \(.*$\)/<div class="code">\1<\/div>/g')";          # one line code
   raw="$(echo "$raw" | sed -e 's/^;tdred \(.*$\)/  <td style="color:red">\1<\/td>/g')";  # <td> (inline)
   raw="$(echo "$raw" | sed -e 's/^;tdgreen \(.*$\)/  <td style="color:green">\1<\/td>/g')";  # <td> (inline)
   raw="$(echo "$raw" | sed -e 's/^;td \(.*$\)/  <td>\1<\/td>/g')";  # <td> (inline)
   raw="$(echo "$raw" | sed -e 's/^;tdl \(.*$\)/  <td style="text-align:left">\1<\/td>/g')";  # <td-l> (inline)
   raw="$(echo "$raw" | sed -e 's/^;tdc \(.*$\)/  <td style="text-align:center">\1<\/td>/g')";  # <td-c> (inline)
   raw="$(echo "$raw" | sed -e 's/^;tdr \(.*$\)/  <td style="text-align: right">\1<\/td>/g')";  # <td-r> (inline)
   raw="$(echo "$raw" | sed -e 's/^;th \(.*$\)/  <th>\1<\/th>/g')";  # <th> (inline)
   raw="$(echo "$raw" | sed -e 's/;br/<br>/g')";                     # <br>
   raw="$(echo "$raw" | sed -e 's/;hr/<hr>/g')";                     # <hr>
   raw="$(echo "$raw" | sed -e '/^;#.*$/d')";                        # comentário, remove a linha 
   # síntaxe: ;x ... ;~x
   raw="$(echo "$raw" | sed -e 's/;i\(.*;~i\)/<i>\1<\/i>/g')";       # itálico      i
   raw="$(echo "$raw" | sed -e 's/;b\(.*;~b\)/<b>\1<\/b>/g')";       # negrito      b
   raw="$(echo "$raw" | sed -e 's/;u\(.*;~u\)/<u>\1<\/u>/g')";       # sublinhado   u
   raw="$(echo "$raw" | sed -e 's/;s\(.*;~s\)/<s>\1<\/s>/g')";       # cortado      s
   raw="$(echo "$raw" | sed -e 's/;m\(.*;~m\)/<mark>\1<\/mark>/g')"; # mark         m
   raw="$(echo "$raw" | sed -e 's/;k\(.*;~k\)/<kbd>\1<\/kbd>/g')";   # key          k
   raw="$(echo "$raw" | sed -e 's/;c\(.*;~c\)/<span class="inline-code">\1<\/span>/g')"; # span code
   # start-enders
   raw="$(echo "$raw" | sed -e 's/;\^ul/<ul>/g')";                   # start UL 
   raw="$(echo "$raw" | sed -e 's/;\$ul/<\/ul>/g')";                 # end UL
   raw="$(echo "$raw" | sed -e 's/;\^C/<div class="code">/g')";      # start code block
   raw="$(echo "$raw" | sed -e 's/;\$C/<\/div>/g')";                 # end code block
   raw="$(echo "$raw" | sed -e 's/;\^table/<table>/g')";             # start table
   raw="$(echo "$raw" | sed -e 's/;\$table/<\/table>/g')";           # end table
   raw="$(echo "$raw" | sed -e 's/;\^tr/ <tr>/g')";                  # start TR
   raw="$(echo "$raw" | sed -e 's/;\$tr/ <\/tr>/g')";                # end TR
   raw="$(echo "$raw" | sed -e 's/;\^td/  <td>/g')";                 # start TD
   raw="$(echo "$raw" | sed -e 's/;\$td/  <\/td>/g')";               # end TD
   # pie chart
   raw="$(echo "$raw" | sed -e 's/;pie "\(.*\)"/<div class="pie" style="background-image: conic-gradient(\1);"><\/div>/g')"; # pie chart
   # links e imagens
   # 				       path 	sty-img  caption  sty-fig 
   raw="$(echo "$raw" | sed -e 's/;fig "\(.*\)" "\(.*\)" "\(.*\)" "\(.*\)"/<figure style="\4"><img src="..\/..\/files\/\1" style="\2"><figcaption>\3<\/figcaption><\/figure>/g')"; # figure
   raw="$(echo "$raw" | sed -e 's/;img "\(.*\)" "\(.*\)"/<img src="..\/..\/files\/\1" style="width:\2">/g')"; # <img src="">
   raw="$(echo "$raw" | sed -e 's/;rimg "\(.*\)" "\(.*\)"/<img src="\1" style="width:\2">/g')"; # <img src="">
   raw="$(echo "$raw" | sed -e 's/;url "\(.*\)" "\(.*\)"/<a target="_blank" href="\1">\2<\/a>/g')"; # <a href=""></a>
   # limpas os ;~. e ^;;
   raw="$(echo "$raw" | sed -e 's/;~.//g')";
   raw="$(echo "$raw" | sed -e 's/^;;//g')";
   # saída
   echo -e "$raw";
}

preparePage() {
   local raw="$1";
   checkRawExists "$raw" || err "Esse raw não existe.";
   local raw_file_path="$RAWDIR/${raw}.txt"; 
   # carrega o template dos articles
   local page_mod="$MODDIR/page.html";
   local base="$(cat "$page_mod")";
   # carrega o hash guardado nos metadados 
   local hash_meta="$(getRawMeta "$raw" --hash)";
   # checa se foi modificado
   local signature_line_number="$(grep -n '<!--ARTICLE-IS-SIGNED-->' "$raw_file_path" | cut -d: -f1)";
   local content_without_signature="$(head -n $(($signature_line_number - 1)) "$raw_file_path")";
   local hash_content="$(echo "$content_without_signature" | sha256sum | cut -d' ' -f1)";
   # atribuir metadados
   local article_title="$(getRawMeta "$raw" --title)";
   local timestamp="$(getRawMeta "$raw" --date-signed)";
   # carregar o conteúdo do raw-*.txt e parsear em html
   local content="$(cat "$raw_file_path")";
   local parsed_content="$(parseToHTML "$content")";
   # construir o campo address
   local nicedate="$(getRawMeta "$raw" --nice-date)";
   nicedate='no-nice-date'; # EVITA O USO DO NICE-DATE
   if [[ "$nicedate" == 'no-nice-date' ]]
   then
      local date="$(date -d @"$timestamp" '+%A, %d/%m/%Y %H:%M')";
      local address="$WEBSITE_AUTOR, $date";
   else
      local address="$nicedate";
   fi
   # última atualização
   local last_update="$(getRawMeta "$raw" --date-updated)";
   if [[ "$last_update" != 'NEVER' ]]
   then
      last_update="$(date -d @$last_update '+%d/%m/%Y %H:%M')";
      last_update='Última atualização: '"$last_update"'<br><br>';
   else
      last_update='';
   fi
   # comments
   local comments="$(cat "$MODDIR/comments.html")";
   local options="$(getRawMeta "$raw" --options)";
   grep 'no-comments' <<< "$options" > /dev/null && comments='';
   # prev e next
   local prev="$(genPrevNext "$raw" --prev)";
   # tags 
   local tags="Tags: $(genTagsSpan "$raw" )";
   local next="$(genPrevNext "$raw" --next)";
   # fazer as substituições no template
   base="${base/@@PAGE-METADATA@@/"$metadata"}";
   base="${base/@@PAGE-TITLE@@/"$article_title"}";
   base="${base/@@PAGE-CONTENT@@/"$parsed_content"}";
   base="${base/@@PAGE-LAST-UPDATE@@/"$last_update"}";
   base="${base/@@PAGE-ADDRESS@@/"$address"}";
   base="${base/@@PAGE-TAGS@@/"$tags"}";
   base="${base/@@PAGE-COMMENTS@@/"$comments"}";
   base="${base/@@PAGE-PREV@@/"$prev"}";
   base="${base/@@PAGE-NEXT@@/"$next"}";
   # retorna a página pronta
   echo -e "$base";
}

compilePage() { # --home or --page
   local home_or_page=$1;
   local raw_index="$2";
   local base_template_path="$LAYOUT";
   # declara os caminhos p/ templates e outros parametros
   local super_title="$WEBSITE_NAME";
   local favicon_url;
   local title="$WEBSITE_NAME";
   local motd_template_path="$MODDIR/motd.html";
   local href_home_url='#';
   local top_nav_template_path="$MODDIR/nav.html";
   local main_template_path;
   local aside_template_path="$MODDIR/aside.html";
   local footer_template_path="$MODDIR/footer.html";
   # top nav url root
   local top_nav="$(cat "$top_nav_template_path")";
   local aside="$(cat "$aside_template_path")";
   if [[ $home_or_page == '--home' ]]
   then
      # configs para buildar a homepage
      top_nav="$(echo $top_nav | sed 's/@URL-ROOT@/./g')";
      aside="$(echo $aside | sed 's/@URL-ROOT@/./g')";
      main_template_path="$MODDIR/home.html";
      main="$(cat "$main_template_path")";
      output_file="$WEBSITE_HOME/index.html";
      css_url_root='./root.css';
      css_url_main='./main.css';
      file_dir_base='./';
      favicon_url='./files/favicon.ico';
      article_list="$(genPostsList)";
      article_list_other="$(genCompactPostsList)";
   elif [[ $home_or_page == '--page' ]]
   then
      # configs para buildar um article (post)
      top_nav="$(echo $top_nav | sed 's/@URL-ROOT@/..\/../g')";
      aside="$(echo $aside | sed 's/@URL-ROOT@/..\/../g')";
      checkRawExists "$raw_index" || err "Esse raw não existe.";
      checkRawIsSigned "$raw_index" || err "Esse raw não está assinado.";
      main="$(preparePage "$raw_index")";
      mkdir "$WEBSITE_PAGES/$raw_index" &> /dev/null;
      output_file="$WEBSITE_PAGES/$raw_index/index.html";
      css_url_root='../../root.css';
      css_url_main='../../main.css';
      file_dir_base='../../';
      favicon_url='../../files/favicon.ico';
      href_home_url='../../index.html';
      # metadados de um article
      local metadata="$(echo "$main" | head -n1)";
      # title na tab
      super_title="SDF: ""$(getRawMeta "$raw_index" --title)";
   fi
      main="${main/@ARTICLE-LIST-CONTENT@/"$article_list"}";
      main="${main/@ARTICLE-LIST-OTHER-CONTENT@/"$article_list_other"}";
   # carrega o conteúdo dos templates para as variáveis
   local base="$(cat "$base_template_path")";
   local motd="$(cat "$motd_template_path")";
   local footer="$(cat "$footer_template_path")";
   # faz as substituições
   base="${base/@SUPER-TITLE-CONTENT@/"$super_title"}";
   base="${base/@CSS-URL-ROOT-CONTENT@/"$css_url_root"}";
   base="${base/@CSS-URL-MAIN-CONTENT@/"$css_url_main"}";
   base="${base/@FAVICON-URL-CONTENT@/"$favicon_url"}";
   base="${base/@FILE-DIR-BASE-CONTENT@/"$file_dir_base"}";
   base="${base/@HREF-HOME-CONTENT@/"$href_home_url"}";
   base="${base/@TITLE-CONTENT@/"$title"}";
   base="${base/@SUBTITLE-CONTENT@/"$subtitle"}";
   base="${base/@MOTD-CONTENT@/"$motd"}";
   base="${base/@TOP-NAV-CONTENT@/"$top_nav"}";
   base="${base/@MAIN-CONTENT@/"$main"}";
   #base="${base/@ASIDE-CONTENT@/"$aside"}"; REMOVE ASIDE!
   base="${base/@ASIDE-CONTENT@/}";
   base="${base/@FOOTER-CONTENT@/"$footer"}";
   # checa se o dir existe e cria
   path_to_output_file="$(dirname "$output_file")";
   [[ -d "$path_to_output_file" ]] || mkdir -p "$path_to_output_file";
   # escreve a saída no arquivo
   echo "$base" > "$output_file";
}

addRSSItem() { # --rss-template --rss-file --raw_index
   local rss_template="$RSS_TEMPLATE";
   local var_rss_list="$RSS_LIST";
   local link_base="$RSS_LINK_BASE";
   local entry="$RSS_ITEM_TEMPLATE";
   # cria um <item>, caso não exista, cria um novo se --force
   # a existencia da entrada é determinada pelo @link@
   local raw="$1";
   checkRawExists "$raw" || err "Esse raw não existe.";
   local force="$2";
   # checar se está assinado
   if ! grep '<!--ARTICLE-IS-SIGNED-->' "$RAWDIR/${raw}.txt" > /dev/null
   then
      echo 'Esse rascunho não está assinado.';
      exit 1;
   fi
   # pega os metadados
   local meta="$(tail -n 1 "$RAWDIR/${raw}.txt")";
   title="$(echo "$meta" | cut -d^ -f2)";
   desc='Atualização.';
   link="$link_base""$raw";
   date="$(echo "$meta" | cut -d^ -f3)";
   #[[ "$date" == 'NEVER' ]] && date="$(echo "$meta" | cut -d^ -f3)";
   local raw_date="$date";
   date="$(date '+%a, %d %b %Y %R:%S %z' -d @$date)";
   options="$(echo "$meta" | cut -d^ -f6)";
   # encerra se a opção i existir
   if grep 'no-rss' <<< "$options" &> /dev/null;
   then
      msg 'no-rss: entrada RSS ignorada.';
      return 1;
   fi
   # substituiçoes no template
   entry="${entry/@TITLE@/"$title"}";
   entry="${entry/@DESC@/"$desc"}";
   entry="${entry/@LINK@/"$link"}";
   entry="${entry/@DATE@/"$date"}";
   entry="${entry/@RAW-DATE@/"$raw_date"}";
   # checa se já existe e se --force foi passado
   # se já existe, só recria com --force
   if ! grep "$link" "$var_rss_list" > /dev/null
   then
      echo -e "$entry" >> "$var_rss_list" && return 0; 
   elif [[ "$force" == '--force' ]]
   then
      sed -i -e "s|^.*$link.*$||" "$var_rss_list";
      echo -e "$entry" >> "$var_rss_list" && return 0; 
      sed -i -e '/^$/d' "$var_rss_list";
   else
      warn 'Entrada RSS já existe.' && return 1;
   fi
}

rebuildRSS() { 
   # recompila o arquivo rss no site
   local rss_file="$(cat "$RSS_TEMPLATE")";
   local rss_list="$(cat "$RSS_LIST" | sort -n -r | sed -e 's/^[[:digit:]]* //g' -e '/^$/d')";
   local last_build="$(date '+%a, %d %b %Y %R:%S %z')";
   # substituiçoes no template
   rss_file="${rss_file/@WEBSITE-NAME@/"$WEBSITE_NAME"}";
   rss_file="${rss_file/@WEBSITE-URL@/"$WEBSITE_URL_RSS"}";
   rss_file="${rss_file/@RSS-DESC@/"$RSS_DESC"}";
   rss_file="${rss_file/@ITEMS-LIST@/"$rss_list"}";
   rss_file="${rss_file/@LAST-BUILD-DATE@/"$last_build"}";
   # escreve o arquivo rss no site
   echo -e "$rss_file" > "$WEBSITE_HOME/rss.xml";
}

makeCover() {
   [[ -n "$1" ]] || err "Uso: arquivo-original nome";
   local orig_file=$1;
   local name="cover-$2";
   local covers_dir="$WEBSITE_FILES";
   # faz a imagem
   convert "$orig_file" -modulate 100,0,100 -colorspace RGB -fill '#97A66E' -tint 100 -resize 50x50 -ordered-dither o8x8 -colors 4 "$covers_dir"/"$name".gif \
      || err "Cover não foi criado.";
}

importFile() {
   [[ -n "$1" ]] || err "Uso: arquivo-original usado-por nome.ext";
   local orig_file="$1";
   local used_by="$2";
   local name="$3";
   local filename="p-$used_by-$name";
   local files_dir="$WEBSITE_FILES";
   # faz a imagem
   cp "$orig_file" "$files_dir/$filename" || err "Arquivo NÃO foi importado.";
}

niceDate() {
   local timestamp="$1";
   # lê o local passado ao wttr.in
   read -p 'wttr.in/' wttr_param;
   # pega o preço do btc
   btc_price="$(curl -sSL "https://mempool.space/api/v1/prices" | jq .USD)";
   # pega o blockheight
   blockheight="$(curl -sSL "https://mempool.space/api/blocks/tip/height")";
   # pega a fee
   fee="$(curl -sSL "https://mempool.space/api/v1/fees/recommended" | jq .fastestFee)";
   # pega o periodo do dia
   hour="$(date -d @"$timestamp" '+%H' | sed 's/^0//')";
   if [[ "$hour" -ge 5 && "$hour" -lt 7 ]]
   then
      period='aurora';
   elif [[ "$hour" -ge 7 && "$hour" -lt 12 ]]
   then
      period='manhã';
   elif [[ "$hour" -ge 12 && "$hour" -lt 17 ]]
   then
      period='tarde';
   elif [[ "$hour" -ge 17 && "$hour" -lt 18 ]]
   then
      period='tardinha';
   elif [[ "$hour" -ge 18 && "$hour" -lt 23 ]]
   then
      period='noite';
   else
      period='madrugada';
   fi
   # pega o dia da semana
   day="$(date -d @"$timestamp" '+%u')";
   days=(PLACEHOLDER segunda-feira terça-feira quarta-feira quinta-feira sexta-feira sábado domingo);
   weekday="${days[$day]}";
   # pega os dados de clima e atribui
   weather="$(curl -s "wttr.in/$wttr_param?format=%c+%f+%C&lang=pt-br")";
   weather="${weather/+/}";
   # data
   legacy_date="$(date -d @"$timestamp" '+%d/%m/%Y %H:%M')";
   # saída
   echo -e "\
   <div>$WEBSITE_AUTOR<br>\
   Bloco $blockheight ($legacy_date $weekday) ($weather) 1₿ valia \$$btc_price, Network fee: ${fee}sat/vB.</div>" | tr -s ' ';
}

compileCSS() {
   css_file='';
   for file in $CSS_TO_COMPILE
   do
     css_file="$css_file\n$(cat $CSSDIR/$file)";
   done   
   # escrever
   echo -e "$css_file" > "$WEBSITE_HOME/main.css";
   # root
   cp "$CSSDIR/$CSS_ROOT_THEME" "$WEBSITE_HOME/root.css";
}

genPrevNext() {
   local raw="$1";
   re='^[0-9]+$'
   if [[ "$raw" =~ $re ]]
   then 
      local prev_next="$2";
      if [[ "$prev_next" == '--prev' ]]
      then
         local sub="Postagem anterior";
         local icon_prev='←';
         local link=$(("$raw-1"));
      elif [[ "$prev_next" == '--next' ]]
      then
         local sub="Próxima postagem";
         local icon_next='→';
         local link=$(("$raw+1"));
      fi
      if getRawMeta "$link" --title > /dev/null 
      then
         local title="$(getRawMeta "$link" --title)";
         echo "<span><a title='$title' href='../${link}/index.html'>$icon_prev $sub $icon_next</a></span>";
      else
         echo '';
      fi
   else
      echo '';
   fi
}

listAllTags() {
   ls $RAWDIR/*.txt &> /dev/null || err "Não há raws.";
   local posts="$(ls $RAWDIR/*.txt)"; 
   local all_tags='';  
   for post_path in ${posts[@]}
   do
      local post="$(extractRawNameFromPath "$post_path")";
      checkRawIsSigned "$post" || continue;
      
      all_tags="$all_tags\n$(getRawMeta "$post" --tags)";
   done
   
   echo -e "$all_tags" | tr ' ' '\n' | sed '/^$/d' | sort -u; 
}

genTagMenu() {
  ls $RAWDIR/*.txt &> /dev/null || err "Não há raws.";
  local posts="$(ls $RAWDIR/*.txt)"; 
  local output='';
  local tag_index_itens='';
  for tag in $(listAllTags)
  do
    [[ "$tag" == 'none' ]] && continue;
    local tag_count=0;
    local tagged_posts='';
      for post_path in ${posts[@]}
      do
        local post="$(extractRawNameFromPath "$post_path")";
        checkRawIsSigned "$post" || continue;
          
        local this_post_tags="$all_tags\n$(getRawMeta "$post" --tags)";
        grep -q "$tag" <<< $this_post_tags || continue

        tag_count="$(($tag_count+1))";
        local this_post_link="$(genCompactPostsList "$post" "--allow-main" | sed -e 's!./r/!../../r/!g')";
        tagged_posts="$tagged_posts\n$this_post_link";
      done
    tagget_posts="$(echo -e "$tagged_posts" | sort -n -k 2)";
    tag_index_itens="$tag_index_itens\n${tag} ($tag_count)";
    output="$output<h3 id='tag-$tag'>$tag ($tag_count)</h3>\n<ul class='posts-list'>";
    output="$output$tagged_posts";
    output="$output\n</ul><br>\n";
  done
  local signature="<!--ARTICLE-IS-SIGNED-->\n<!--^Tags^1738682103^🏷^NEVER^hidden no-rss no-comments unlisted^e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855^ <div>Saindo da Falha<br> Bloco 882294 (04/02/2025 12:15 terça-feira) (☀ 32°C Ensolarado) 1₿ valia $99320, Network fee: 4sat/vB.</div>^none^-->";
  
  # index
  local tag_index='Lista de tags: <ul class="mono posts-list">';
  oifs=$IFS;
  IFS=$'\n';
  for tag_link in $(echo -e "$tag_index_itens")
  do
    tag_index="$tag_index\n<li><a href='#tag-$(echo "$tag_link" | cut -d' ' -f 1)'>$tag_link</a></li> ";
  done
  tag_index="$tag_index</ul><br>";
  IFS=$oifs;

  # gerar
  echo -e "$tag_index\n$output\n$signature" | sed -e '/^$/d' -e 's/<\/ul>/<\/ul>\n/g' -e 's/^/;;/g' > "$RAWDIR/tags.txt" && msg "Tags raw updated. Compile it.";
  ./sdfc.sh -u tags -y
}

genTagsSpan() {
   local raw="$1";
   for tag in $(getRawMeta "$raw" --tags | tr ' ' '\n' | sort);
   do
      echo -e "<a href='../tags/index.html#tag-$tag'>$tag</a> ";
   done
}

showHelp() {
   echo -e "\
   -w       criar ou editar raw
   -s       assinar raw
   -u       atualizar raw (assinar novamente)
   -l       listar raws
   -c       compilar raw, criar entrada RSS, atualizar tudo (-r)
   -r       atualizar tudo (recompilar: CSS, RSS e home)
   -R       compilar (-c) todos os raws e atualizar tudo
   -css     recompilar CSS
   -rss     recompilar RSS
   -h       help";
}

# TOOLS 
resizeGif() {
   local input="$1";
   local name="$2";
   local size="$3";
   gifsicle --resize-fit-width "$size" -i "$input" > "$WEBSITE_FILES/$name";
}

cropImg() {
   local input="$1";
   local name="$2";
   local size="$3";
   magick "$input" -crop "$size"x"$size"+0+0 "$WEBSITE_FILES/$name";
}

resizeImg() {
   local input="$1";
   local name="$2";
   local size="$3";
   magick "$input" -resize "$size"x"$size" "$WEBSITE_FILES/$name";
}

genJournalEntry() {
  local date="$1";
  local content="$2";

  echo -e "
;;<div class="journal-item">
;;<b>"$date"</b><br>
;;<div class="journal-border">
;;"$content"
;;</div> </div> <br>
  ";
}

txt2journal() {
  [[ -n "$1" ]] && local txt="$(cat "$1")" || local txt="$(cat "$VARDIR/journal.txt")";
  
  local html="$(echo -e "$txt\n" | sed -e 's/^\(..\/..\/....\)/<div class="journal-item">\n <b>\1<\/b><br>\n <ul class="journal-border">/' -e 's/^  - \(.*\)$/  <li>\1<\/li>/' -e 's/^$/ <\/ul>\n<\/div>\n/' | sed -e 's/^/;;/' -e 's/^;;$/\n/')";
  
  local intro='Do francês <i>journal</i>, do latim <i>diurnalis</i>, diário. Relatos diários.<br> Atualizações <s>quase</s> diárias do que venho <s>ou não</s> fazendo para sair da falha.<br><br>';
  
  echo -e "$intro\n$html\n";
}

updateJournal() {
  local signatures="$(sed '1,/<!--ARTICLE-IS-SIGNED-->/d' "$RAWDIR/journal.txt")";
  local journals="$(./sdfc.sh --txt2journal)";
  echo -e "$journals\n\n<!--ARTICLE-IS-SIGNED-->\n$signatures" > "$RAWDIR/journal.txt";
  ./sdfc.sh -u journal -y;
  ./sdfc.sh -c journal;
}

# FUNÇÕES DE ATALHO
writeOrCreateRaw() {
   local raw="$1";
   if ! checkRawExists "$raw" 
   then
      msg "Este raw não existe. Criar?";
      read -p 'Criar (y)? ' 
      [[ "$REPLY" == 'y' ]] && createRaw "$raw" || exit 0;
   fi
   checkRawIsSigned "$raw" && editRaw "$raw" || writeRaw "$raw";
}

updateAll() {
   compileCSS && msg 'CSS recompilado.' || warn 'CSS NÃO foi recompilado.';
   rebuildRSS && msg 'RSS recompilado.' || warn 'RSS NÃO foi recompilado.';
   compilePage --home && msg 'Home recompilada.' || warn 'Home NÃO foi recompilada.';
}


compile() {
   local raw="$1";
   checkRawExists "$raw" || err "Esse raw não existe.";
   local forceRSS="$2";
   compilePage --page "$raw" && msg "Página $raw foi compilada." || err "Págia $raw NÃO foi compilada."; 
   addRSSItem "$raw" "$forceRSS" && msg "Entrada RSS criada." || warn "Entrada RSS NÃO foi criada."; 
   echo;
}

compileAndUpdateAll() {
   local raw="$1";
   checkRawExists "$raw" || err "Esse raw não existe.";
   local forceRSS="$2";
   compile "$raw" "$forceRSS";
   updateAll;
}

compileAllAndUpdateAll() {
   ls "$RAWDIR" &> /dev/null || err "Não há raws.";
   local posts="$(ls "$RAWDIR")"; 
   for post in ${posts[@]}
   do
      post=${post/raw-/};
      post=${post/.txt/};
      checkRawIsSigned "$post" && compile "$post";
   done
   updateAll;
}

# FUNÇÃO MAIN
main() {
   # inicialização
   [[ "$(pwd)" == $ROOTDIR ]] || 
      err "Este script não pode ser executado neste diretório.";
   ensureDir $LAYDIR;
   ensureDir $MODDIR;
   ensureDir $CSSDIR;
   ensureDir $RSSDIR;
   ensureDir $VARDIR;
   ensureDir $RAWDIR;
   ensureDir $WWWDIR;
   ensureDir $WEBSITE_ROOT;
   ensureDir $WEBSITE_HOME;
   ensureDir $WEBSITE_FILES;
   ensureDir $WEBSITE_PAGES;
   # interface
   case $1 in
      --create-raw)           createRaw "$2"                ;;
      --write-raw)            writeRaw "$2"                 ;;
      --edit-raw)             editRaw "$2"                  ;;
      --list-raws)            listRaws                      ;;
      --list-unsigned-raws)   listUnsignedRaws              ;;
      --sign-raw)             signRaw "$2"                  ;;
      --get-raw-meta)         getRawMeta "$2" "$3"          ;;
      --update-raw-signature) updateRawSignature "$2"       ;;
      --prepare-page)         preparePage "$2"              ;;
      --compile-page-page)    compilePage --page "$2"       ;;
      --compile-page-home)    compilePage --home            ;;
      --gen-posts-list)       genPostsList                  ;;
      --gen-compact-posts-list) genCompactPostsList "$2" "$3" ;;
      --add-rss-item)         addRSSItem "$2"               ;;
      --rebuild-rss)          rebuildRSS                    ;;
      --make-cover )          makeCover "$2" "$3"           ;;
      --nice-date)            niceDate "$2"                 ;;
      --compile-css)          compileCSS                    ;;
      --get-raw-meta)         getRawMeta "$2" "$3"          ;;
      --gen-prev-next)        genPrevNext "$2" "$3"         ;;
      --import-file)          importFile "$2" "$3" "$4"     ;;
      --list-all-tags)        listAllTags                   ;;
      --gen-tag-menu)         genTagMenu                    ;;
      # shotcuts *******************************************;;
      -w)                     writeOrCreateRaw "$2"         ;;
      -s)                     signRaw "$2"                  ;;
      -u)                     updateRawSignature "$2" "$3"  ;;
      -l)                     listRaws "$2"                 ;;
      -c)                     compileAndUpdateAll "$2" "$3" ;;
      -r)                     updateAll                     ;;
      -R)                     compileAllAndUpdateAll        ;;
      -t)                     genTagMenu                    ;;
      -j)                     updateJournal                 ;;
      -css)                   compileCSS                    ;;
      -rss)                   rebuildRSS                    ;;
      -if)                    importFile "$2" "$3" "$4"     ;;
      -mc)                    makeCover "$2" "$3"           ;;
      # tools    *******************************************;;
      --resize-gif)           resizeGif "$2" "$3" "$4"      ;;
      --crop-img)             cropImg "$2" "$3" "$4"        ;;
      --resize-img)           resizeImg "$2" "$3" "$4"      ;;
      --gen-journal-entry)    genJournalEntry "$2" "$3"     ;;
      --txt2journal)          txt2journal "$2"              ;;
      --update-journal)       updateJournal                 ;;
      -h | --help)            showHelp                      ;;
      *)                      msg "$VERSION   Help: -h"     ;;
   esac
}

main $@;
