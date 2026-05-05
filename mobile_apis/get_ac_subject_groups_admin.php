<?php
/**
 * Subject groups (admin) list, including subjects and class-sections.
 * GET (optional): api_secret when AC_API_SECRET is set.
 */
require_once __DIR__ . '/ac_admin_bootstrap.php';

$mysqli = null;
try {
    $mysqli = ac_mysqli_connect();
    ac_require_api_secret(array_merge($_GET, array()));

    $session_id = ac_current_session_id($mysqli);
    if ($session_id <= 0) {
        throw new Exception('Could not resolve current session.');
    }

    $groups = array();
    $r = $mysqli->query(
        'SELECT id, name, description
         FROM subject_groups
         WHERE session_id = ' . (int) $session_id . '
         ORDER BY id DESC'
    );
    if ($r) {
        while ($row = $r->fetch_assoc()) {
            $gid = (int) $row['id'];

            $subjects = array();
            $rs = $mysqli->query(
                'SELECT sgs.subject_id, sub.name, sub.code, sub.type
                 FROM subject_group_subjects sgs
                 INNER JOIN subjects sub ON sub.id = sgs.subject_id
                 WHERE sgs.subject_group_id = ' . $gid . '
                   AND sgs.session_id = ' . (int) $session_id . '
                 ORDER BY sub.name ASC'
            );
            if ($rs) {
                while ($s = $rs->fetch_assoc()) {
                    $subjects[] = array(
                        'subject_id' => (int) $s['subject_id'],
                        'name' => (string) ($s['name'] ?? ''),
                        'code' => (string) ($s['code'] ?? ''),
                        'type' => (string) ($s['type'] ?? ''),
                    );
                }
            }

            $class_sections = array();
            $rcs = $mysqli->query(
                'SELECT sgcs.class_section_id, cs.class_id, cs.section_id, c.class AS class_name, sec.section AS section_name
                 FROM subject_group_class_sections sgcs
                 INNER JOIN class_sections cs ON cs.id = sgcs.class_section_id
                 INNER JOIN classes c ON c.id = cs.class_id
                 INNER JOIN sections sec ON sec.id = cs.section_id
                 WHERE sgcs.subject_group_id = ' . $gid . '
                   AND sgcs.session_id = ' . (int) $session_id . '
                 ORDER BY cs.class_id ASC, cs.section_id ASC'
            );
            if ($rcs) {
                while ($cs = $rcs->fetch_assoc()) {
                    $class_sections[] = array(
                        'class_section_id' => (int) $cs['class_section_id'],
                        'class_id' => (int) $cs['class_id'],
                        'section_id' => (int) $cs['section_id'],
                        'class_name' => (string) ($cs['class_name'] ?? ''),
                        'section_name' => (string) ($cs['section_name'] ?? ''),
                    );
                }
            }

            $groups[] = array(
                'id' => $gid,
                'name' => (string) ($row['name'] ?? ''),
                'description' => (string) ($row['description'] ?? ''),
                'subjects' => $subjects,
                'class_sections' => $class_sections,
            );
        }
    }

    $mysqli->close();
    ac_admin_success(array(
        'current_session_id' => $session_id,
        'items' => $groups,
    ));
} catch (Exception $e) {
    if ($mysqli) $mysqli->close();
    ac_admin_fail($e->getMessage(), array('current_session_id' => 0, 'items' => array()));
}

