#!/usr/bin/env nextflow

params.str = 'Hello Slurm!'

process splitLetters {

    output:
    file 'chunk_*' into letters

    """
    sleep 5
    printf '${params.str}' | split -b 6 - chunk_
    sleep 5
    """
}


process convertToUpper {

    input:
    file x from letters.flatten()

    output:
    stdout result

    """
    sleep 5
    cat $x | tr '[a-z]' '[A-Z]'
    sleep 5
    """
}

result.view { it.trim() }
