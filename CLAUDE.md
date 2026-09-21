# CLAUDE.md — dotfiles

개인 dotfiles 저장소. 사용자 문서는 `README.org`, 설치 동작의 정답은 항상
`install.sh`다. 이 파일에는 그 둘을 읽어도 놓치기 쉬운 것, 즉 **여기서
작업할 때 실제로 틀리는 것**만 적는다.

## 심볼릭 링크가 아니라 복사다

`install.sh`는 관리 대상 파일을 `$HOME`, `~/.config`, `~/.claude`로
**복사**한다. 그래서 저장소 파일을 고쳐도 설치된 복사본은 그대로고,
반대로 설치본을 고쳐도 저장소는 그대로다.

- 고치는 대상은 언제나 **저장소 쪽**이다 (`dotconfig/...`, `dotclaude/...`,
  루트의 `.bashrc` 등). `~/.config/bash/init` 같은 설치본을 직접 고치면
  다음 설치 때 덮인다.
- 반영은 `./install.sh <component>`. 이건 `$HOME`을 건드리므로 **직접
  실행하지 말고 사용자에게 제안**한다 (요청받으면 실행해도 된다).
- 컴포넌트 목록: `./install.sh --list`

| 저장소 | 설치 위치 | 컴포넌트 |
|---|---|---|
| `.bashrc` `.bash_profile` `.profile` `.zshrc` | `$HOME` | `bash` / `zsh` |
| `dotconfig/<app>/` | `~/.config/<app>/` | `bash` `zsh` `doom` `ghostty` |
| `bin/mkshellenv` | `~/.local/bin/` | `shellenv` |
| `.gitconfig` `.clang-format` | `$HOME` | `git` / `clang-format` |
| `dotclaude/` | `~/.claude/` | `claude` (양방향) |

## `dotclaude/` vs `.claude/` — 헷갈리지 말 것

- **`dotclaude/`** 는 설치 대상 페이로드다. `dotclaude/CLAUDE.md`가
  사용자의 **전역** Claude 규칙(`~/.claude/CLAUDE.md`)이다. "전역 규칙을
  바꿔달라"는 요청은 여기를 고치고 `./install.sh claude`로 반영한다.
- **`.claude/`** (저장소 루트)는 이 저장소에서 작업할 때만 쓰는 프로젝트
  설정이다. 어떤 컴포넌트에도 들어 있지 않아 **설치되지 않는다**. 루트의
  이 `CLAUDE.md`도 마찬가지.
- `claude` 컴포넌트만 **양방향 동기화**(최신 mtime 우선)다. `./install.sh
  claude`가 `~/.claude` 쪽 편집본을 저장소로 끌어올 수 있으니, 실행했으면
  `git diff dotclaude/`로 무엇이 들어왔는지 확인한다. `git pull`은 파일
  mtime을 새로 찍으므로 **pull 전에** 이 동기화를 먼저 돌려야 로컬 편집이
  살아남는다.

## 커밋하지 않는 것

- `dotconfig/{bash,zsh}/env`, `dotconfig/{bash,zsh}/private` — `mkshellenv`가
  머신마다 생성하거나 사용자가 손으로 두는 것. `.gitignore`에 있다.
- `~/.gitconfig.local`, `~/.config/doom/{local,custom}.el` — 머신 로컬이라
  저장소에 존재하지 않는다.
- `install.sh`가 남긴 `<file>.backup`.

## 셸 이식성 — 여기서 제일 자주 깨진다

macOS의 `/bin/bash`는 **3.2**다. 대화형 셸이 읽는 파일은 3.2에서
**파싱**까지 통과해야 한다. 파싱 단계에서 깨지면 그 머신의 모든 셸
시작마다 에러가 뜬다 (실제 사례: `git show e96fcda` — extglob `@(...)`).

대상: `.bashrc`, `.bash_profile`, `dotconfig/bash/*`, `dotconfig/zsh/*`

- 금지: extglob(`@()`, `+()`), `${var,,}` / `${var^^}`, 연관 배열
  (`declare -A`), `mapfile` / `readarray`. `case`, `tr`, `while read`로 쓴다.
- `.profile`은 bash가 아니라 **POSIX sh**다 (파일 상단 `# shellcheck
  shell=sh`). bash 전용 문법 전부 금지.
- macOS와 Linux 양쪽에서 돌아야 한다. 차이는 `$OSTYPE` 분기로 인라인
  처리한다 (Homebrew vs Linuxbrew, `ls -G` vs `ls --color=auto`,
  `/etc/bashrc` vs `/etc/bash.bashrc`).
- `install.sh`와 `bin/mkshellenv`는 `#!/usr/bin/env bash`로 실행된다. 새
  머신에서는 그게 `/bin/bash` 3.2일 수 있으니 여기도 3.2에서 돌아야 한다.
- 자기 파일이 아닌 변수(`$_backup_glob` 같은 bash-completion 내부 변수)에
  기대지 않는다. 로드 순서가 바뀌면 조용히 빈 값이 된다.

## 검증

이 저장소의 커밋은 본문에 **무엇을 어떻게 검증했는지** 적는다. 셸 쪽을
고쳤으면 실제로 두 bash에서 돌려보고 그 결과를 커밋 메시지에 남긴다.

```sh
shellcheck install.sh bin/mkshellenv            # 새 지적을 만들지 않는다
shellcheck -s bash dotconfig/bash/*             # 셰뱅이 없으므로 -s bash
/bin/sh -n .profile                             # POSIX sh
/bin/bash -n dotconfig/bash/init                # 3.2 파싱
/opt/homebrew/bin/bash -n dotconfig/bash/init   # 5.x 파싱
/bin/bash -lc '. dotconfig/bash/init'           # 3.2에서 실제 로드
./install.sh --list                             # 설치 없이 컴포넌트 확인
```

동작이 바뀌면 `README.org`의 해당 절도 같이 고친다 — 설치 규칙과 셸 구성은
거기에 상세히 문서화돼 있고, 지금까지 코드와 함께 갱신해 왔다.

## Doom Emacs

`dotconfig/doom/` → `~/.config/doom/`. `init.el`(활성 모듈)이나
`packages.el`을 고쳤으면 설치 후 **`doom sync`가 필요**하다. `config.el`만
고친 경우는 필요 없다. 패키지 recipe를 손댔으면 straight의 build 디렉토리
레이아웃까지 확인한다 (`git show b91fcaf` — `:files`를 넓혀야 했던 사례).

## 커밋

- Conventional Commits, **영문 제목**. scope는 영역 이름을 쓴다:
  `bash`, `zsh`, `doom`, `install`, `shellenv`, `claude`, `git`
- 본문에 **왜**와 **검증한 것**을 쓴다. 길이 기준은 기존 커밋이다
  (`git log -3 85ac50b`).
- AI attribution 트레일러는 붙이지 않는다 (전역 규칙).
- 커밋은 요청받았을 때만. push는 필요하면 해도 된다.
