# 📸 ProRAW Studio (Pro Camera Enhancement for iOS)

Aplicativo nativo para iOS focado em processar arquivos **Apple ProRAW (.DNG)** diretamente no hardware do iPhone (Core Image + Metal), desativando os filtros artificiais da Apple (*over-sharpening*, *plastic skin smoothing* e *HDR plano*) e reconstruindo a imagem com o visual de **câmeras profissionais (Leica / Sony Alpha / Arri)**.

---

## 🚀 Como Compilar e Instalar no seu iPhone (Sem precisar de Mac)

Este projeto está 100% preparado para ser compilado gratuitamente na nuvem via **GitHub Actions** e instalado pelo Windows usando o **Sideloadly**.

---

### Passo 1: Subir o Projeto para o seu GitHub

1. Abra o terminal (PowerShell ou Git Bash) nesta pasta:
   ```powershell
   cd C:\Users\scrip\.gemini\antigravity\scratch\ProRawEnhancer
   ```
2. Inicialize o repositório Git e faça o commit:
   ```powershell
   git init
   git add .
   git commit -m "Initial commit ProRAW Studio"
   ```
3. Crie um novo repositório no seu [GitHub](https://github.com/new) (pode ser **Público** ou **Privado**).
4. Vincule e envie os arquivos:
   ```powershell
   git branch -M main
   git remote add origin https://github.com/SEU_USUARIO/NOME_DO_REPOSITORIO.git
   git push -u origin main
   ```

---

### Passo 2: Baixar o `.IPA` gerado pelo GitHub Actions

1. No seu repositório no GitHub, clique na aba **"Actions"** no topo.
2. Você verá o workflow **"Build iOS App (.IPA)"** rodando.
3. Aguarde cerca de 1 a 2 minutos até que fique verde (concluído com sucesso).
4. Clique na execução da Action e role até o final da página na seção **"Artifacts"**.
5. Clique em **`ProRawEnhancer-IPA`** para baixar o arquivo `.zip` (que contém o `ProRawEnhancer.ipa`).

---

### Passo 3: Instalar no iPhone usando o Windows (Sideloadly)

1. Baixe e instale o [Sideloadly](https://sideloadly.io/) no seu Windows (é gratuito e seguro).
2. Conecte o iPhone ao PC pelo cabo USB.
3. Abra o **Sideloadly**:
   * O seu iPhone será detectado automaticamente.
   * Digite o seu **Apple ID** (o mesmo que você usa no iPhone).
   * Arraste o arquivo `ProRawEnhancer.ipa` para dentro da janela do Sideloadly.
   * Clique em **Start**.
4. Quando terminar, o ícone do **ProRAW Film** estará na tela inicial do seu iPhone!

> **Primeira abertura no iPhone:**
> Vá em `Ajustes` > `Geral` > `VPN e Gerenciamento de Dispositivo` > Clique no seu Apple ID e toque em **"Confiar"**.

---

## 🎨 O que o Algoritmo Faz?

* **Zero Over-Sharpening:** Elimina os halos brancos e contornos recortados do iPhone.
* **Micro-Contraste Óptico:** Realça texturas finas reais (fios de cabelo, poros da pele, tecidos e folhagens).
* **Highlight Roll-off Cinematográfico:** Curva tonal S que suaviza o brilho de lâmpadas e do céu, evitando o estouro digital branco seco.
* **Grão Óptico Suave:** Textura orgânica de sensor de cinema, eliminando o aspecto de aquarela/plástico da redução de ruído padrão.
* **Comparador Antes/Depois:** Divisor deslizante interativo para inspecionar cada detalhe antes de exportar.
