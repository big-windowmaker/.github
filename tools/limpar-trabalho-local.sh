#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# limpar-trabalho-local.sh — arruma os clones locais dos repositórios do
# Big WindowMaker: worktrees e branches que já estão no branch padrão do
# origin saem; o resto é só listado para uma decisão humana.
#
#   limpar-trabalho-local.sh [--aplicar] [DIRETÓRIO]
#
# DIRETÓRIO: a pasta com os clones (padrão: o diretório atual). Sem
# --aplicar, só mostra o que faria.
#
# Remove (com --aplicar):
#   - worktrees extras com a árvore limpa (nem arquivo novo) cujo HEAD já
#     está no branch padrão do origin, também por squash/rebase (git cherry);
#   - branches locais nas mesmas condições, sem worktree;
#   - registros de worktrees cujas pastas não existem mais (git worktree prune).
# Muda o checkout principal para o branch padrão quando ele está limpo e o
# branch atual já foi incorporado.
#
# Só lista: branches com commits fora do padrão (enviados ou não), worktrees
# com alterações, pastas antigas de packages/out e caches grandes.
set -uo pipefail

aplicar=0
raiz=.
for a in "$@"; do
	case $a in
	--aplicar) aplicar=1 ;;
	-h | --help)
		sed -n '4,22p' "$0" | sed 's/^# \{0,1\}//'
		exit 0
		;;
	*) raiz=$a ;;
	esac
done
raiz=$(cd "$raiz" && pwd) || exit 1

fazer() { # descrição, comando...
	local d=$1
	shift
	if ((aplicar)); then
		if "$@" >/dev/null 2>&1; then echo "  ✔ $d"; else echo "  ✘ falhou: $d"; fi
	else
		echo "  · $d"
	fi
}

# O HEAD (ou branch) já está em $padrao: ancestral, ou todos os commits com
# patch equivalente lá (squash/rebase).
incorporado() { # repo ref padrao
	git -C "$1" merge-base --is-ancestor "$2" "$3" 2>/dev/null && return 0
	! git -C "$1" cherry "$3" "$2" 2>/dev/null | grep -q '^+'
}

limpo() { [ -z "$(git -C "$1" status --porcelain 2>/dev/null)" ]; }

removidos=0 listados=0
for repo in "$raiz"/*/; do
	repo=${repo%/}
	[ -e "$repo/.git" ] || continue
	[ -d "$repo/.git" ] || continue # só o checkout principal (worktrees têm .git arquivo)
	nome=${repo##*/}
	git -C "$repo" remote get-url origin >/dev/null 2>&1 || continue
	git -C "$repo" fetch -q --prune origin 2>/dev/null
	padrao=$(git -C "$repo" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)
	[ -n "$padrao" ] || padrao=origin/main
	git -C "$repo" rev-parse -q --verify "$padrao" >/dev/null || continue
	echo "== $nome ($padrao)"
	git -C "$repo" worktree prune

	# worktrees extras
	declare -A em_worktree=()
	principal=$(git -C "$repo" rev-parse --show-toplevel)
	while read -r caminho; do
		ramo=$(git -C "$caminho" symbolic-ref -q --short HEAD 2>/dev/null)
		[ -n "$ramo" ] && em_worktree[$ramo]=1
		[ "$caminho" = "$principal" ] && continue
		if limpo "$caminho" && incorporado "$caminho" HEAD "$padrao"; then
			# Com submódulos (wlmaker), o git só remove com --force, mesmo
			# limpa; a árvore já foi conferida acima.
			forca=()
			[ -f "$caminho/.gitmodules" ] && forca=(--force)
			fazer "worktree $caminho${ramo:+ ($ramo)}" git -C "$repo" worktree remove "${forca[@]}" "$caminho"
			if [ -n "$ramo" ]; then
				unset "em_worktree[$ramo]"
				fazer "branch $ramo" git -C "$repo" branch -D "$ramo"
			fi
			removidos=$((removidos + 1))
		else
			motivo="commits fora do $padrao"
			limpo "$caminho" || motivo="alterações não salvas"
			echo "  ? fica: worktree $caminho${ramo:+ ($ramo)}: $motivo"
			listados=$((listados + 1))
		fi
	done < <(git -C "$repo" worktree list --porcelain | sed -n 's/^worktree //p')

	# checkout principal no branch padrão
	atual=$(git -C "$repo" symbolic-ref -q --short HEAD)
	local_padrao=${padrao#origin/}
	if [ "$atual" = "$local_padrao" ]; then
		limpo "$repo" && ((aplicar)) && git -C "$repo" merge -q --ff-only "$padrao" >/dev/null 2>&1
	elif [ -n "${em_worktree[$local_padrao]:-}" ] && [ "$atual" != "" ]; then
		echo "  ? checkout principal fica em $atual ($local_padrao está aberto noutra worktree)"
		listados=$((listados + 1))
	elif git -C "$repo" rev-parse -q --verify "refs/heads/$local_padrao" >/dev/null &&
		! git -C "$repo" merge-base --is-ancestor "refs/heads/$local_padrao" "$padrao"; then
		echo "  ? checkout principal fica em ${atual:-HEAD solto} ($local_padrao local tem commits fora do $padrao)"
		listados=$((listados + 1))
	elif limpo "$repo" && incorporado "$repo" HEAD "$padrao"; then
		fazer "checkout principal: ${atual:-HEAD solto} → $local_padrao" \
			git -C "$repo" checkout -q -B "$local_padrao" "$padrao"
	else
		echo "  ? checkout principal fica em ${atual:-HEAD solto} (alterações não salvas ou commits fora do $padrao)"
		listados=$((listados + 1))
	fi
	atual=$(git -C "$repo" symbolic-ref -q --short HEAD)

	# branches sem worktree
	while read -r ramo; do
		[ "$ramo" = "$local_padrao" ] || [ "$ramo" = "$atual" ] || [ -n "${em_worktree[$ramo]:-}" ] && continue
		if incorporado "$repo" "refs/heads/$ramo" "$padrao"; then
			fazer "branch $ramo" git -C "$repo" branch -D "$ramo"
			removidos=$((removidos + 1))
		else
			n=$(git -C "$repo" cherry "$padrao" "refs/heads/$ramo" 2>/dev/null | grep -c '^+')
			up=$(git -C "$repo" for-each-ref --format='%(upstream:short)' "refs/heads/$ramo")
			quando=$(git -C "$repo" log -1 --format=%cs "refs/heads/$ramo")
			echo "  ? fica: branch $ramo: $n commit(s) fora do $padrao, último em $quando, ${up:-SEM upstream (nunca enviado)}"
			listados=$((listados + 1))
		fi
	done < <(git -C "$repo" for-each-ref --format='%(refname:short)' refs/heads)
	unset em_worktree
done

echo
if [ -d "$raiz/packages/out" ]; then
	echo "== packages/out: pastas com mais de 14 dias (apague à mão o que não for mais instalar)"
	find "$raiz/packages/out" -mindepth 1 -maxdepth 1 -mtime +14 -exec du -sh {} + 2>/dev/null | sort -h | tail -20
fi
for c in "$HOME/.cache/bwm-wt" "$HOME/.cache/bwm-perf"; do
	[ -d "$c" ] && echo "== cache $(du -sh "$c" 2>/dev/null | cut -f1) em $c"
done
echo
if ((aplicar)); then
	echo "Feito: $removidos removido(s); $listados item(ns) para decidir."
else
	echo "Simulação: $removidos a remover; $listados item(ns) para decidir. Rode com --aplicar."
fi
