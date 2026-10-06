begin
   comment json2dir evaluator in ALGOL 60 (GNU MARST).
   Reads the input from channel 0 (stdin) as a decimal byte count, one
   whitespace character and then exactly that many bytes. Checks strict
   UTF-8, parses and validates the whole JSON document by hand and writes
   a POSIX sh script to channel 1 (stdout). The last line of a complete
   script is the end marker line. Errors call fault, which
   prints a message on stderr and aborts with a non-zero status.
   Bytes are read and written through inchar and outchar with a string
   holding the bytes 1 to 255 in order, so the position of a character
   in it is its byte value. inchar reports NUL as position 256 (the
   terminator of the string);
   integer n;

   procedure fail(msg);
      string msg;
      fault(msg, 0);

   ininteger(0, n);
   if n < 0 then fail("bad input length");

   begin
      integer array inb[1:n+1], pool[1:n+1],
         nkind, nstart, nlen, nmfirst, nmcount[1:n+1],
         mnames, mnamel, mval[1:n+1], objmem, pend[1:n+1],
         path[1:2*n+2];
      integer pos, pooltop, nodetop, memtop, objtop, pendtop, pathtop,
         strs, strl, root, i, c, dummy;

      comment ---- byte input and output ----;

      integer procedure getbyte;
      begin
         integer p;
         inchar(0,
            "\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017"
            "\020\021\022\023\024\025\026\027\030\031\032\033\034\035\036\037"
            "\040\041\042\043\044\045\046\047\050\051\052\053\054\055\056\057"
            "\060\061\062\063\064\065\066\067\070\071\072\073\074\075\076\077"
            "\100\101\102\103\104\105\106\107\110\111\112\113\114\115\116\117"
            "\120\121\122\123\124\125\126\127\130\131\132\133\134\135\136\137"
            "\140\141\142\143\144\145\146\147\150\151\152\153\154\155\156\157"
            "\160\161\162\163\164\165\166\167\170\171\172\173\174\175\176\177"
            "\200\201\202\203\204\205\206\207\210\211\212\213\214\215\216\217"
            "\220\221\222\223\224\225\226\227\230\231\232\233\234\235\236\237"
            "\240\241\242\243\244\245\246\247\250\251\252\253\254\255\256\257"
            "\260\261\262\263\264\265\266\267\270\271\272\273\274\275\276\277"
            "\300\301\302\303\304\305\306\307\310\311\312\313\314\315\316\317"
            "\320\321\322\323\324\325\326\327\330\331\332\333\334\335\336\337"
            "\340\341\342\343\344\345\346\347\350\351\352\353\354\355\356\357"
            "\360\361\362\363\364\365\366\367\370\371\372\373\374\375\376\377",
            p);
         getbyte := if p = 256 then 0 else p
      end getbyte;

      procedure putbyte(b);
         value b; integer b;
         outchar(1,
            "\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017"
            "\020\021\022\023\024\025\026\027\030\031\032\033\034\035\036\037"
            "\040\041\042\043\044\045\046\047\050\051\052\053\054\055\056\057"
            "\060\061\062\063\064\065\066\067\070\071\072\073\074\075\076\077"
            "\100\101\102\103\104\105\106\107\110\111\112\113\114\115\116\117"
            "\120\121\122\123\124\125\126\127\130\131\132\133\134\135\136\137"
            "\140\141\142\143\144\145\146\147\150\151\152\153\154\155\156\157"
            "\160\161\162\163\164\165\166\167\170\171\172\173\174\175\176\177"
            "\200\201\202\203\204\205\206\207\210\211\212\213\214\215\216\217"
            "\220\221\222\223\224\225\226\227\230\231\232\233\234\235\236\237"
            "\240\241\242\243\244\245\246\247\250\251\252\253\254\255\256\257"
            "\260\261\262\263\264\265\266\267\270\271\272\273\274\275\276\277"
            "\300\301\302\303\304\305\306\307\310\311\312\313\314\315\316\317"
            "\320\321\322\323\324\325\326\327\330\331\332\333\334\335\336\337"
            "\340\341\342\343\344\345\346\347\350\351\352\353\354\355\356\357"
            "\360\361\362\363\364\365\366\367\370\371\372\373\374\375\376\377",
            b);

      comment ---- helpers ----;

      integer procedure peek;
         peek := if pos <= n then inb[pos] else -1;

      procedure skipws;
         for dummy := 0 while peek = 32 | peek = 9 | peek = 10 | peek = 13 do
            pos := pos + 1;

      procedure push(b);
         value b; integer b;
      begin
         pooltop := pooltop + 1;
         pool[pooltop] := b
      end push;

      procedure checkutf8;
      begin
         integer i, b, need, lo, hi, k;
         i := 1;
         for dummy := 0 while i <= n do
         begin
            b := inb[i]; need := 0; lo := 128; hi := 191;
            if b < 128 then need := 0
            else if b >= 194 & b <= 223 then need := 1
            else if b = 224 then begin need := 2; lo := 160 end
            else if b >= 225 & b <= 236 then need := 2
            else if b = 237 then begin need := 2; hi := 159 end
            else if b >= 238 & b <= 239 then need := 2
            else if b = 240 then begin need := 3; lo := 144 end
            else if b >= 241 & b <= 243 then need := 3
            else if b = 244 then begin need := 3; hi := 143 end
            else fail("input is not valid UTF-8");
            i := i + 1;
            for k := 1 step 1 until need do
            begin
               if i > n then fail("input is not valid UTF-8");
               if inb[i] < lo | inb[i] > hi then
                  fail("input is not valid UTF-8");
               lo := 128; hi := 191;
               i := i + 1
            end
         end
      end checkutf8;

      procedure putcp(cp);
         value cp; integer cp;
      begin
         if cp < 128 then push(cp)
         else if cp < 2048 then
         begin
            push(192 + cp % 64); push(128 + cp - (cp % 64) * 64)
         end
         else if cp < 65536 then
         begin
            push(224 + cp % 4096); push(128 + (cp % 64) - (cp % 4096) * 64);
            push(128 + cp - (cp % 64) * 64)
         end
         else
         begin
            push(240 + cp % 262144);
            push(128 + (cp % 4096) - (cp % 262144) * 64);
            push(128 + (cp % 64) - (cp % 4096) * 64);
            push(128 + cp - (cp % 64) * 64)
         end
      end putcp;

      integer procedure hexval(c);
         value c; integer c;
         hexval := if c >= 48 & c <= 57 then c - 48
            else if c >= 97 & c <= 102 then c - 87
            else if c >= 65 & c <= 70 then c - 55
            else -1;

      integer procedure hex4;
      begin
         integer k, v, h;
         v := 0;
         for k := 1 step 1 until 4 do
         begin
            h := hexval(peek);
            if h < 0 then fail("invalid \\u escape");
            v := v * 16 + h;
            pos := pos + 1
         end;
         hex4 := v
      end hex4;

      comment parses a JSON string at pos into the pool (strs, strl);
      procedure parsestring;
      begin
         integer c, done, cp, lo;
         if peek != 34 then fail("expected a string");
         pos := pos + 1;
         strs := pooltop + 1;
         done := 0;
         for dummy := 0 while done = 0 do
         begin
            c := peek;
            if c < 0 then fail("unterminated string");
            pos := pos + 1;
            if c = 34 then done := 1
            else if c < 32 then fail("control character in string")
            else if c != 92 then push(c)
            else
            begin
               c := peek;
               pos := pos + 1;
               if c = 34 then push(34)
               else if c = 92 then push(92)
               else if c = 47 then push(47)
               else if c = 98 then push(8)
               else if c = 102 then push(12)
               else if c = 110 then push(10)
               else if c = 114 then push(13)
               else if c = 116 then push(9)
               else if c = 117 then
               begin
                  cp := hex4;
                  if cp >= 56320 & cp <= 57343 then
                     fail("unpaired surrogate escape");
                  if cp >= 55296 & cp <= 56319 then
                  begin
                     if peek != 92 then fail("unpaired surrogate escape");
                     pos := pos + 1;
                     if peek != 117 then fail("unpaired surrogate escape");
                     pos := pos + 1;
                     lo := hex4;
                     if lo < 56320 | lo > 57343 then
                        fail("unpaired surrogate escape");
                     cp := 65536 + (cp - 55296) * 1024 + (lo - 56320)
                  end;
                  putcp(cp)
               end
               else fail("invalid escape in string")
            end
         end;
         strl := pooltop - strs + 1
      end parsestring;

      integer procedure poolhas(s, l, b);
         value s, l, b; integer s, l, b;
      begin
         integer k, r;
         r := 0;
         for k := 0 step 1 until l - 1 do
            if pool[s + k] = b then r := 1;
         poolhas := r
      end poolhas;

      integer procedure islink(s, l);
         value s, l; integer s, l;
         islink := if l != 4 then 0
            else if pool[s] = 108 & pool[s+1] = 105 & pool[s+2] = 110
               & pool[s+3] = 107 then 1 else 0;

      integer procedure isscript(s, l);
         value s, l; integer s, l;
         isscript := if l != 6 then 0
            else if pool[s] = 115 & pool[s+1] = 99 & pool[s+2] = 114
               & pool[s+3] = 105 & pool[s+4] = 112 & pool[s+5] = 116
            then 1 else 0;

      integer procedure isdots(s, l);
         value s, l; integer s, l;
         isdots := if l = 1 then (if pool[s] = 46 then 1 else 0)
            else if l = 2 then
               (if pool[s] = 46 & pool[s+1] = 46 then 1 else 0)
            else 0;

      comment compares two member names by their UTF-8 bytes;
      integer procedure namecmp(a, b);
         value a, b; integer a, b;
      begin
         integer k, la, lb, r;
         la := mnamel[a]; lb := mnamel[b];
         r := 0; k := 0;
         for dummy := 0 while r = 0 & k < la & k < lb do
         begin
            r := pool[mnames[a] + k] - pool[mnames[b] + k];
            k := k + 1
         end;
         if r = 0 then r := la - lb;
         namecmp := r
      end namecmp;

      comment node kinds: 0 object, 1 file, 2 link, 3 script;
      integer procedure newnode(kind, s, l);
         value kind, s, l; integer kind, s, l;
      begin
         nodetop := nodetop + 1;
         nkind[nodetop] := kind; nstart[nodetop] := s; nlen[nodetop] := l;
         nmfirst[nodetop] := 0; nmcount[nodetop] := 0;
         newnode := nodetop
      end newnode;

      integer procedure parsevalue(depth);
         value depth; integer depth;
      begin
         integer c, node, base, done, ns, nl, v, i, j, t, kind;
         if depth > 1000 then fail("document is nested too deeply");
         skipws;
         c := peek;
         if c = 34 then
         begin
            parsestring;
            node := newnode(1, strs, strl)
         end
         else if c = 91 then
         begin
            pos := pos + 1;
            skipws;
            parsestring;
            kind := if islink(strs, strl) = 1 then 2
               else if isscript(strs, strl) = 1 then 3 else 0;
            if kind = 0 then
               fail("an array must be [\"link\", target] or [\"script\", content]");
            skipws;
            if peek != 44 then fail("an array must have exactly two strings");
            pos := pos + 1;
            skipws;
            parsestring;
            skipws;
            if peek != 93 then fail("an array must have exactly two strings");
            pos := pos + 1;
            if kind = 2 & strl = 0 then fail("a link target cannot be empty");
            if kind = 2 then
            begin
               if poolhas(strs, strl, 0) = 1 then
                  fail("a link target cannot contain NUL")
            end;
            node := newnode(kind, strs, strl)
         end
         else if c = 123 then
         begin
            pos := pos + 1;
            skipws;
            base := pendtop;
            if peek = 125 then pos := pos + 1
            else
            begin
               done := 0;
               for dummy := 0 while done = 0 do
               begin
                  skipws;
                  parsestring;
                  ns := strs; nl := strl;
                  if nl = 0 then fail("empty name");
                  if isdots(ns, nl) = 1 then fail("name . or .. is not allowed");
                  if poolhas(ns, nl, 47) = 1 then fail("a name cannot contain /");
                  if poolhas(ns, nl, 0) = 1 then fail("a name cannot contain NUL");
                  skipws;
                  if peek != 58 then fail("expected :");
                  pos := pos + 1;
                  v := parsevalue(depth + 1);
                  memtop := memtop + 1;
                  mnames[memtop] := ns; mnamel[memtop] := nl; mval[memtop] := v;
                  pendtop := pendtop + 1;
                  pend[pendtop] := memtop;
                  skipws;
                  c := peek;
                  pos := pos + 1;
                  if c = 125 then done := 1
                  else if c != 44 then fail("expected , or }")
               end
            end;
            comment stable insertion sort of the members of this object by name;
            for i := base + 2 step 1 until pendtop do
            begin
               t := pend[i];
               j := i - 1;
               for dummy := 0 while
                  (if j > base then namecmp(pend[j], t) > 0 else false) do
               begin
                  pend[j + 1] := pend[j];
                  j := j - 1
               end;
               pend[j + 1] := t
            end;
            node := newnode(0, 0, 0);
            nmfirst[node] := objtop + 1;
            nmcount[node] := pendtop - base;
            for i := base + 1 step 1 until pendtop do
            begin
               objtop := objtop + 1;
               objmem[objtop] := pend[i]
            end;
            pendtop := base
         end
         else fail("only objects, strings and [kind, payload] arrays are allowed");
         parsevalue := node
      end parsevalue;

      comment ---- shell output ----;

      comment a single-quoted shell word, NUL bytes split the payload
         into separate words, which the script joins with NUL again;
      procedure putquoted(s, l);
         value s, l; integer s, l;
      begin
         integer k, b;
         outstring(1, "'");
         for k := 0 step 1 until l - 1 do
         begin
            b := pool[s + k];
            if b = 0 then outstring(1, "' '")
            else if b = 39 then outstring(1, "'\\''")
            else putbyte(b)
         end;
         outstring(1, "'")
      end putquoted;

      procedure putpath;
      begin
         integer k, b;
         outstring(1, "'");
         for k := 1 step 1 until pathtop do
         begin
            b := path[k];
            if b = 39 then outstring(1, "'\\''") else putbyte(b)
         end;
         outstring(1, "'")
      end putpath;

      procedure emit(node);
         value node; integer node;
      begin
         integer i, m, v, k, plen, skip;
         for i := 0 step 1 until nmcount[node] - 1 do
         begin
            m := objmem[nmfirst[node] + i];
            comment duplicate names: the last occurrence wins;
            skip := 0;
            if i + 1 < nmcount[node] then
            begin
               if namecmp(m, objmem[nmfirst[node] + i + 1]) = 0 then skip := 1
            end;
            if skip = 0 then
            begin
               v := mval[m];
               plen := pathtop;
               if plen > 0 then
               begin
                  pathtop := pathtop + 1;
                  path[pathtop] := 47
               end;
               for k := 0 step 1 until mnamel[m] - 1 do
               begin
                  pathtop := pathtop + 1;
                  path[pathtop] := pool[mnames[m] + k]
               end;
               if nkind[v] = 0 then
               begin
                  outstring(1, "_j2d_dir ");
                  putpath;
                  outstring(1, "\n");
                  emit(v)
               end
               else
               begin
                  if nkind[v] = 1 then outstring(1, "_j2d_file ")
                  else if nkind[v] = 2 then outstring(1, "_j2d_link ")
                  else outstring(1, "_j2d_script ");
                  putpath;
                  outstring(1, " ");
                  putquoted(nstart[v], nlen[v]);
                  outstring(1, "\n")
               end;
               pathtop := plen
            end
         end
      end emit;

      comment ---- main ----;

      for i := 1 step 1 until n do inb[i] := getbyte;
      checkutf8;
      pos := 1;
      pooltop := 0; nodetop := 0; memtop := 0; objtop := 0; pendtop := 0;
      pathtop := 0;
      comment a leading byte order mark is ignored (RFC 8259 permits it);
      if n >= 3 then
      begin
         if inb[1] = 239 & inb[2] = 187 & inb[3] = 191 then pos := 4
      end;
      skipws;
      if peek != 123 then fail("the root of the document must be an object");
      root := parsevalue(0);
      skipws;
      if pos <= n then fail("trailing data after the JSON value");

      outstring(1, "set -eu\n");
      outstring(1, "_j2d_fail() { printf 'json2dir: cannot create \045s\\n' \"$1\" >&2; exit 1; }\n");
      outstring(1, "# Remove an existing non-directory (a symlink itself, never its target);\n");
      outstring(1, "# a real directory in the way of a non-object is an error.\n");
      outstring(1, "_j2d_clear() {\n");
      outstring(1, "  if [ -L \"$1\" ]; then rm -f -- \"$1\" || _j2d_fail \"$1\"\n");
      outstring(1, "  elif [ -d \"$1\" ]; then printf 'json2dir: a directory is in the way: \045s\\n' \"$1\" >&2; exit 1\n");
      outstring(1, "  elif [ -e \"$1\" ]; then rm -f -- \"$1\" || _j2d_fail \"$1\"\n");
      outstring(1, "  fi\n");
      outstring(1, "}\n");
      outstring(1, "_j2d_dir() {\n");
      outstring(1, "  if [ -L \"$1\" ] || { [ -e \"$1\" ] && [ ! -d \"$1\" ]; }; then rm -f -- \"$1\" || _j2d_fail \"$1\"; fi\n");
      outstring(1, "  if [ ! -d \"$1\" ]; then mkdir -- \"$1\" || _j2d_fail \"$1\"; fi\n");
      outstring(1, "}\n");
      outstring(1, "# _j2d_file path part...: the content is the parts joined by NUL bytes.\n");
      outstring(1, "_j2d_file() {\n");
      outstring(1, "  _j2d_clear \"$1\"\n");
      outstring(1, "  _j2d_path=$1; shift\n");
      outstring(1, "  {\n");
      outstring(1, "    printf '\045s' \"$1\"; shift\n");
      outstring(1, "    for _j2d_part in \"$@\"; do printf '\\000\045s' \"$_j2d_part\"; done\n");
      outstring(1, "  } > \"$_j2d_path\" || _j2d_fail \"$_j2d_path\"\n");
      outstring(1, "}\n");
      outstring(1, "_j2d_script() { _j2d_file \"$@\"; chmod a+x -- \"$1\" || _j2d_fail \"$1\"; }\n");
      outstring(1, "_j2d_link() { _j2d_clear \"$1\"; ln -s -- \"$2\" \"$1\" || _j2d_fail \"$1\"; }\n");
      emit(root);
      outstring(1, "# json2dir: end\n")
   end
end
