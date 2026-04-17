# Teste Em VM

## Resumo

Este projeto agora tem dois jeitos de testar:

1. `./test.sh`
   Cria uma VM limpa Ubuntu via Multipass e roda um smoke test automatizado do fluxo CLI.

2. VM Desktop manual
   Valida o que realmente importa para este repositório: GNOME, `gsettings`, `flatpak`, `nautilus-share`, `samba`, fontes, temas e reboot.

O teste manual em Ubuntu Desktop continua sendo o mais importante. O teste via Multipass não cobre interface gráfica.

## Recomendação Principal

Use `virt-manager` com uma VM de `Ubuntu 24.04 Desktop`.

Configuração sugerida:

- `2 vCPU`
- `4 GB RAM` no mínimo
- `30 GB` de disco
- snapshot logo após a instalação limpa do Ubuntu

Se quiser algo mais simples, `GNOME Boxes` também serve. Mas `virt-manager` é melhor para snapshot, inspeção e repetição de testes.

## Teste Automatizado Com VM Limpa

O script [`test.sh`](/home/silver/dev/new-linux-fresh-config/test.sh) usa `Multipass` por padrão.

Ele faz isto:

- instala `multipass` via `snap` se necessário
- cria uma VM Ubuntu limpa
- monta este repositório dentro da VM
- valida sintaxe dos scripts
- valida `./install.sh --list-themes`
- executa `./install.sh`

Uso básico:

```bash
./test.sh
```

Manter a VM depois do teste:

```bash
./test.sh --keep-vm
```

Escolher release e tamanho da VM:

```bash
./test.sh --release=24.04 --cpus=2 --memory=4G --disk=30G
```

Smoke test em container:

```bash
./test.sh --mode=container
```

## Limitações Do Teste Automatizado

O modo Multipass valida bem:

- Ubuntu limpo
- `sudo`
- `apt`
- instalação das ferramentas CLI
- fluxo real do `install.sh` fora de container

Ele não valida:

- GNOME
- `gsettings`
- `flameshot` shortcut
- `nautilus-share`
- `samba` integrado ao desktop
- fontes aplicadas visualmente
- temas do Omakub no GNOME
- reboot pós-instalação

## Procedimento De Teste Completo Em Ubuntu Desktop

1. Crie uma VM com `Ubuntu 24.04 Desktop`.
2. Faça login e rode atualização básica do sistema.
3. Tire um snapshot chamado `clean-install`.
4. Clone este repositório na VM.
5. Rode:

```bash
chmod +x install.sh
./install.sh --theme=tokyo-night
```

6. Reinicie a VM.
7. Valide os itens abaixo.

## Checklist Pós-Instalação

- `gh`, `eza`, `batcat`, `bun`, `uv`, `composer`, `podman` instalados
- alias `ls="eza"` presente no `~/.bashrc`
- alias `bat="batcat"` presente no `~/.bashrc`
- aliases `copy` e `paste` presentes
- `flatpak` funcionando
- apps desktop instalados
- `flameshot` associado à tecla `Print`
- fontes copiadas para `~/.local/share/fonts/new-linux-fresh-config`
- `fc-cache` executado sem erro
- `samba` instalado
- `smbclient` instalado
- usuário no grupo `sambashare`
- `nautilus-share` disponível no Nautilus
- tema aplicado no GNOME
- wallpaper alterado

## Estratégia Recomendada

Use os dois testes:

- `./test.sh` para regressão rápida em VM limpa
- VM Desktop manual para validar integração real do ambiente gráfico

## Troubleshooting

### Multipass cai logo ao iniciar

Se o host estiver com `/etc/resolv.conf` apontando para `Valet Linux`, o `multipassd` pode falhar ao subir o `dnsmasq`.

Sinal típico:

- `failed to open file ... multipass_root_cert.pem`
- `snap services multipass` alternando entre `active` e `inactive`
- `journalctl -u snap.multipass.multipassd` mostrando erro do `dnsmasq`

No host afetado, verifique:

```bash
ls -l /etc/resolv.conf
```

Se ele apontar para algo como `/opt/valet-linux/resolv.conf`, troque temporariamente para um arquivo regular e rode o teste de novo:

```bash
sudo rm -f /etc/resolv.conf
printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' | sudo tee /etc/resolv.conf >/dev/null
sudo snap restart multipass.multipassd
./test.sh
```

Depois do teste, restaure o setup do Valet se você ainda precisar dele.
