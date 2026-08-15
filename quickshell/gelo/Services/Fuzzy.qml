// Fuzzy subsequence scoring, shared by every launcher provider.
//
// Extracted from Apps so the clipboard provider ranks identically — two search
// boxes in the same palette that sort differently is worse than either one on
// its own.
//
// Subsequence matching, the shape Raycast/Linear/fzf use: every query character
// must appear in order, and the score rewards matches that start a word, matches
// that run contiguously, and short haystacks. That is what makes "gim" put gimp
// above "GNOME Image Manipulation Program".

pragma Singleton

import Quickshell
import QtQuick

Singleton {
    // Returns -1 for no match, otherwise higher is better.
    function score(haystack, needle) {
        if (needle.length === 0)
            return 0;

        const h = haystack.toLowerCase();
        const n = needle.toLowerCase();

        // Whole-string prefix is the strongest possible signal.
        if (h.startsWith(n))
            return 1000 - h.length;

        let hi = 0;
        let total = 0;
        let run = 0;

        for (let ni = 0; ni < n.length; ni++) {
            const c = n[ni];
            let found = -1;

            while (hi < h.length) {
                if (h[hi] === c) {
                    found = hi;
                    break;
                }
                hi++;
            }

            if (found === -1)
                return -1;

            let points = 1;

            // Word-start match: beginning of the string, or after a separator.
            const prev = found > 0 ? h[found - 1] : " ";
            if (found === 0 || prev === " " || prev === "-" || prev === "_" || prev === ".")
                points += 8;

            // Contiguous run with the previous matched character.
            if (run > 0 && found === hi && ni > 0)
                points += 4 + run;

            run = (ni > 0 && found === hi) ? run + 1 : 1;
            total += points;
            hi = found + 1;
        }

        // Prefer shorter haystacks among otherwise equal matches.
        return total * 10 - h.length;
    }
}
