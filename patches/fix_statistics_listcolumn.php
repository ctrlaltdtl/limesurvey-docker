<?php
/**
 * LimeSurvey 7.0.0 bug: statistics_helper._listcolumn() receives field names
 * with internal type prefixes (TQ9, SQ9, UQ9, etc.) but uses them directly as
 * DB column names. The actual DB columns don't have the prefix (Q9, Q9, etc.).
 *
 * Fix: strip the single-char type prefix when the second character is 'Q',
 * matching the same pattern used elsewhere in statistics_helper.php (line 938).
 */

$file = '/var/www/html/limesurvey/application/helpers/admin/statistics_helper.php';
$content = file_get_contents($file);

$old = '    function _listcolumn($surveyid, $column, $sortby = "", $sortmethod = "", $sorttype = "")
    {
        $search[\'condition\'] = Yii::app()->db->quoteColumnName($column) . " != \'\'"';

$new = '    function _listcolumn($surveyid, $column, $sortby = "", $sortmethod = "", $sorttype = "")
    {
        // Strip internal statistics type prefix (T/S/U/M/P/N/etc.) to get actual DB column name
        if (strlen($column) > 1 && $column[1] === \'Q\') {
            $column = substr($column, 1);
        }
        $search[\'condition\'] = Yii::app()->db->quoteColumnName($column) . " != \'\'"';

if (strpos($content, $old) !== false) {
    file_put_contents($file, str_replace($old, $new, $content));
    echo "Patch applied successfully.\n";
} elseif (strpos($content, 'Strip internal statistics type prefix') !== false) {
    echo "Patch already applied.\n";
} else {
    echo "ERROR: target pattern not found — patch may need updating for this LimeSurvey version.\n";
    exit(1);
}
