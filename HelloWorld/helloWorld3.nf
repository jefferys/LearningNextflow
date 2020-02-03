#!/usr/bin/env nextflow

params.str = 'Hello world!'

process splitLetters {

    output:
    file 'chunk_*' into letters

    """
    sleep 2
    printf '${params.str}' | split -b 6 - chunk_
    sleep 2
    """
}


process convertToUpper {

    input:
    file x from letters.flatten()

    output:
    stdout result

    """
    sleep 2
    cat $x | tr '[a-z]' '[A-Z]'
    sleep 2
    """
}

result.view { it.trim() }
