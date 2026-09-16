// build-min.mjs — gera versões minificadas do OMNI a partir dos arquivos-fonte,
// sem alterar os originais. Uso: node build-min.mjs <entrada.html> <saida.min.html>
import { minify } from "html-minifier-terser";
import { readFileSync, writeFileSync } from "fs";

const [, , inPath, outPath] = process.argv;
if (!inPath || !outPath) {
  console.error("Uso: node build-min.mjs <entrada.html> <saida.min.html>");
  process.exit(1);
}

const src = readFileSync(inPath, "utf8");

const result = await minify(src, {
  collapseWhitespace: true,
  removeComments: true,
  removeRedundantAttributes: true,
  removeScriptTypeAttributes: true,
  removeStyleLinkTypeAttributes: true,
  useShortDoctype: true,
  minifyCSS: true,
  minifyJS: {
    // Conservador de propósito: NÃO usar toplevel mangle. Isso preserva os
    // nomes de todas as funções/variáveis globais (as mesmas chamadas em
    // onclick="..." no HTML, por exemplo), evitando quebrar qualquer
    // referência cruzada entre HTML e JS. Só remove comentários, espaços
    // e aplica otimizações seguras de sintaxe.
    compress: {
      toplevel: false,
      sequences: true,
      dead_code: true,
      unused: false, // não remove "código não usado" no nível global — risco de remover algo referenciado só pelo HTML
    },
    mangle: false, // não renomeia NADA — máxima segurança, ainda remove comentários/espaços
  },
});

writeFileSync(outPath, result, "utf8");

const before = Buffer.byteLength(src, "utf8");
const after = Buffer.byteLength(result, "utf8");
console.log(`${inPath}`);
console.log(`  antes: ${before.toLocaleString("pt-BR")} bytes`);
console.log(`  depois: ${after.toLocaleString("pt-BR")} bytes`);
console.log(`  reducao: ${(100 - (after / before) * 100).toFixed(1)}%`);
