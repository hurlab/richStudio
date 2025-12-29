# RichStudio
R Shiny app for integrative enrichment analysis and visualization of multiple gene datasets

How to use the app:
1. Visit hosted version on http://hurlab.med.und.edu:3838/richStudio
2. Clone the repository and running the following in R console:

```R
renv::restore()
devtools::load_all()
RichStudio::launch_RichStudio()
```

In the future, we hope to publish the app as a package.
   
## App Overview:
### Upload files

You can upload either DEG sets or enrichment results to the app from your local machine

<img width="876" alt="Screenshot 2024-05-13 at 6 06 08 PM" src="https://github.com/hyuncat/RichStudio/assets/114366569/78189534-7e41-4795-a0eb-5676e5edb25a">

File upload automatically guesses element delimiter based on file type, but can also be specified.

Also accepts a text input list of significant genes, which can be delimited by any non-alphanumeric character.

Valid input examples:
-	 “Xkr4, Rp1, Sox17,    Mrpl15” 
-	“Xkr4, () Rp1, Sox17,  &* Mrpl15”

Uploaded and created files can be exported as .txt, .csv, and .tsv file formats.

 
### Enrichment

<img width="141" align="left" alt="image" src="https://github.com/hyuncat/RichStudio/assets/114366569/1efc8e80-91de-4b4e-99d4-2b83131b0c9b">

Perform gene enrichment from DEG sets or gene lists. 

Supported annotation databases: GO, KEGG, Reactome.

Supported ontologies: BF, MF, CC

20 different supported species (human, mouse, pig, etc.)

<br clear="left"/>
 
## Visualizations
### Enrichment results
Bar plot

<img width="223" alt="image" src="https://github.com/hyuncat/RichStudio/assets/114366569/01b091c1-9560-4c6d-9a6d-7f262a768e03">

Dot plot

<img width="226" alt="image" src="https://github.com/hyuncat/RichStudio/assets/114366569/33c8d20a-e27c-45ef-8f6e-9c7382b7f42d">

Network plot

<img width="244" alt="image" src="https://github.com/hyuncat/RichStudio/assets/114366569/dca9c2ba-28f2-451b-adc1-808bf93a359a">

Heatmap

### Cluster
Uses Cohen's Kappa (bassd on geneID overlap) as a similarity metric between biological terms for use in clustering enriched terms.

<img width="172" alt="image" src="https://github.com/hyuncat/RichStudio/assets/114366569/9568791e-eba4-4fa3-bd14-defda223ef91">


### Cluster results
Comprehensive cluster heatmap

<img width="303" alt="image" src="https://github.com/hyuncat/RichStudio/assets/114366569/cf36a6ec-ec08-456d-8b4c-d042c8dc9cbb">

### Team
Junguk Hur, Ph.D. (Principal Investigator)
Kai Guo, Ph.D. (Software developer; lead)
Sarah Hong (Software developer)
Jane Kim (Software developer)


