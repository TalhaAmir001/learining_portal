<?php
/**
 * Create a share batch (share_contents + share_upload_contents + share_content_for),
 * matching admin Content::share / generate_url behaviour.
 *
 * POST JSON body:
 * {
 *   "title": "...",
 *   "share_date": "YYYY-MM-DD",
 *   "valid_upto": "YYYY-MM-DD",
 *   "description": "",
 *   "send_to": "public|group|class|individual",
 *   "upload_content_ids": [1,2],
 *   "created_by": 0,
 *   "group_ids": ["student","3"],
 *   "class_section_ids": [12],
 *   "individuals": [{"category":"student","record_id":5,"parent_id":0}]
 * }
 *
 * For send_to=public, group_ids/class_section_ids/individuals must be empty.
 * Returns shared_url (portal link) when send_to is public (same encryption as Enc_lib).
 */

header('Content-Type: application/json; charset=utf-8');

function dc_share_send_json($data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode response']);
    } else {
        echo $json;
    }
}

function dc_share_resolve_staff_id(mysqli $mysqli, int $requested): array {
    if ($requested > 0) {
        $st = $mysqli->prepare('SELECT id FROM staff WHERE id = ? LIMIT 1');
        if ($st) {
            $st->bind_param('i', $requested);
            $st->execute();
            $st->store_result();
            if ($st->num_rows > 0) {
                $st->close();
                return ['id' => $requested, 'note' => 'used_client_staff_id'];
            }
            $st->close();
        }
    }
    $r = $mysqli->query('SELECT id FROM staff ORDER BY id ASC LIMIT 1');
    if ($r && $row = $r->fetch_assoc()) {
        $fid = (int) $row['id'];
        if ($fid > 0) {
            return [
                'id' => $fid,
                'note' => $requested > 0
                    ? 'client_id_not_in_staff_table_used_first_staff_row'
                    : 'no_client_id_used_first_staff_row',
            ];
        }
    }
    return ['id' => 0, 'note' => 'no_staff_rows'];
}

function dc_share_encrypt_id(int $id): string {
    $pvt_key = 'ss@pvtkey';
    $pub_key = 'ss@pubkey';
    $encrypt_method = 'AES-256-CBC';
    $key = hash('sha256', $pvt_key);
    $iv = substr(hash('sha256', $pub_key), 0, 16);
    $string = (string) $id;
    $enc = openssl_encrypt($string, $encrypt_method, $key, 0, $iv);
    if ($enc === false) {
        return '';
    }
    return base64_encode($enc);
}

function dc_share_base_url(): string {
    $https = !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off';
    $scheme = $https ? 'https' : 'http';
    $host = $_SERVER['HTTP_HOST'] ?? 'portal.gcsewithrosi.co.uk';
    return $scheme . '://' . $host;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    dc_share_send_json(['success' => false, 'error' => 'Method not allowed']);
    exit;
}

$raw = file_get_contents('php://input');
$input = json_decode($raw, true);
if (!is_array($input)) {
    $input = $_POST;
}

$title = isset($input['title']) ? trim((string) $input['title']) : '';
$share_date = isset($input['share_date']) ? trim((string) $input['share_date']) : '';
$valid_upto = isset($input['valid_upto']) ? trim((string) $input['valid_upto']) : '';
$description = isset($input['description']) ? (string) $input['description'] : '';
$send_to = isset($input['send_to']) ? trim((string) $input['send_to']) : '';
$created_by_req = isset($input['created_by']) ? (int) $input['created_by'] : 0;

$uploadIds = $input['upload_content_ids'] ?? [];
if (!is_array($uploadIds)) {
    $uploadIds = [];
}
$uploadIds = array_values(array_unique(array_map('intval', $uploadIds)));
$uploadIds = array_filter($uploadIds, static function ($v) {
    return $v > 0;
});

$group_ids = $input['group_ids'] ?? [];
if (!is_array($group_ids)) {
    $group_ids = [];
}
$class_section_ids = $input['class_section_ids'] ?? [];
if (!is_array($class_section_ids)) {
    $class_section_ids = [];
}
$class_section_ids = array_values(array_unique(array_map('intval', $class_section_ids)));
$class_section_ids = array_filter($class_section_ids, static function ($v) {
    return $v > 0;
});

$individuals = $input['individuals'] ?? [];
if (!is_array($individuals)) {
    $individuals = [];
}

if ($title === '' || $share_date === '' || $valid_upto === '' || $send_to === '') {
    dc_share_send_json(['success' => false, 'error' => 'Missing title, share_date, valid_upto, or send_to.']);
    exit;
}
if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $share_date) || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $valid_upto)) {
    dc_share_send_json(['success' => false, 'error' => 'share_date and valid_upto must be YYYY-MM-DD.']);
    exit;
}
if (!in_array($send_to, ['public', 'group', 'class', 'individual'], true)) {
    dc_share_send_json(['success' => false, 'error' => 'send_to must be public, group, class, or individual.']);
    exit;
}
if (count($uploadIds) === 0) {
    dc_share_send_json(['success' => false, 'error' => 'upload_content_ids must contain at least one id.']);
    exit;
}

if ($send_to === 'public') {
    if (count($group_ids) > 0 || count($class_section_ids) > 0 || count($individuals) > 0) {
        dc_share_send_json(['success' => false, 'error' => 'For send_to=public, omit group_ids, class_section_ids, and individuals.']);
        exit;
    }
} elseif ($send_to === 'group') {
    if (count($group_ids) === 0) {
        dc_share_send_json(['success' => false, 'error' => 'group_ids is required when send_to is group.']);
        exit;
    }
    foreach ($group_ids as $gid) {
        $s = (string) $gid;
        if (!preg_match('/^(student|parent|\d+)$/', $s)) {
            dc_share_send_json(['success' => false, 'error' => 'Invalid group_id value: ' . $s]);
            exit;
        }
    }
} elseif ($send_to === 'class') {
    if (count($class_section_ids) === 0) {
        dc_share_send_json(['success' => false, 'error' => 'class_section_ids is required when send_to is class.']);
        exit;
    }
} elseif ($send_to === 'individual') {
    if (count($individuals) === 0) {
        dc_share_send_json(['success' => false, 'error' => 'individuals is required when send_to is individual.']);
        exit;
    }
}

$mysqli = null;
try {
    $mysqli = new mysqli(
        'localhost',
        'portal_beta',
        'X7&?C%Yx5[L-QyiL',
        'portal_beta'
    );
    if ($mysqli->connect_error) {
        throw new Exception('Database connection failed: ' . $mysqli->connect_error);
    }
    $mysqli->set_charset('utf8mb4');

    $resolved = dc_share_resolve_staff_id($mysqli, $created_by_req);
    if ($resolved['id'] <= 0) {
        $mysqli->close();
        dc_share_send_json(['success' => false, 'error' => 'No staff row to use as created_by.']);
        exit;
    }
    $created_by = $resolved['id'];

    $inList = implode(',', $uploadIds);
    $chk = $mysqli->query('SELECT COUNT(*) AS c FROM upload_contents WHERE id IN (' . $inList . ')');
    if (!$chk) {
        throw new Exception('Upload check failed: ' . $mysqli->error);
    }
    $crow = $chk->fetch_assoc();
    if ((int) ($crow['c'] ?? 0) !== count($uploadIds)) {
        $mysqli->close();
        dc_share_send_json(['success' => false, 'error' => 'One or more upload_content_ids do not exist.']);
        exit;
    }

    $ownRes = $mysqli->query('SELECT id, upload_by FROM upload_contents WHERE id IN (' . $inList . ')');
    if (!$ownRes) {
        throw new Exception('Ownership check failed: ' . $mysqli->error);
    }
    while ($orow = $ownRes->fetch_assoc()) {
        if ((int) ($orow['upload_by'] ?? 0) !== (int) $created_by) {
            $mysqli->close();
            dc_share_send_json([
                'success' => false,
                'error' => 'You can only share files uploaded under your staff account. Each selected file\'s uploader must match the share creator.',
            ]);
            exit;
        }
    }

    if ($send_to === 'class' && count($class_section_ids) > 0) {
        $csIn = implode(',', $class_section_ids);
        $csc = $mysqli->query('SELECT COUNT(*) AS c FROM class_sections WHERE id IN (' . $csIn . ')');
        if (!$csc) {
            throw new Exception('Class section check failed: ' . $mysqli->error);
        }
        $csrow = $csc->fetch_assoc();
        if ((int) ($csrow['c'] ?? 0) !== count($class_section_ids)) {
            $mysqli->close();
            dc_share_send_json(['success' => false, 'error' => 'One or more class_section_ids do not exist.']);
            exit;
        }
    }

    $mysqli->begin_transaction();

    $stmt = $mysqli->prepare(
        'INSERT INTO share_contents (send_to, title, share_date, valid_upto, description, created_by, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())'
    );
    if (!$stmt) {
        throw new Exception('Prepare failed: ' . $mysqli->error);
    }
    $stmt->bind_param('sssssi', $send_to, $title, $share_date, $valid_upto, $description, $created_by);
    if (!$stmt->execute()) {
        $errno = $stmt->errno;
        $err = $stmt->error;
        $stmt->close();
        $mysqli->rollback();
        $mysqli->close();
        dc_share_send_json([
            'success' => false,
            'error' => 'Failed to create share_contents row.',
            'mysql_errno' => $errno,
            'mysql_error' => $err,
        ]);
        exit;
    }
    $share_id = (int) $stmt->insert_id;
    $stmt->close();

    $insUp = $mysqli->prepare('INSERT INTO share_upload_contents (upload_content_id, share_content_id) VALUES (?, ?)');
    if (!$insUp) {
        throw new Exception('Prepare share_upload_contents failed: ' . $mysqli->error);
    }
    foreach ($uploadIds as $uid) {
        $u = (int) $uid;
        $insUp->bind_param('ii', $u, $share_id);
        if (!$insUp->execute()) {
            $errno = $insUp->errno;
            $err = $insUp->error;
            $insUp->close();
            $mysqli->rollback();
            $mysqli->close();
            dc_share_send_json([
                'success' => false,
                'error' => 'Failed to link upload_content_id ' . $u,
                'mysql_errno' => $errno,
                'mysql_error' => $err,
            ]);
            exit;
        }
    }
    $insUp->close();

    if ($send_to === 'group') {
        foreach ($group_ids as $gid) {
            $g = $mysqli->real_escape_string((string) $gid);
            if (!$mysqli->query("INSERT INTO share_content_for (group_id, share_content_id) VALUES ('$g', $share_id)")) {
                throw new Exception('share_content_for insert failed: ' . $mysqli->error);
            }
        }
    } elseif ($send_to === 'class') {
        foreach ($class_section_ids as $csid) {
            $cid = (int) $csid;
            if (!$mysqli->query("INSERT INTO share_content_for (class_section_id, share_content_id) VALUES ($cid, $share_id)")) {
                throw new Exception('share_content_for insert failed: ' . $mysqli->error);
            }
        }
    } elseif ($send_to === 'individual') {
        foreach ($individuals as $ind) {
            if (!is_array($ind)) {
                continue;
            }
            $cat = isset($ind['category']) ? trim((string) $ind['category']) : '';
            $rid = isset($ind['record_id']) ? (int) $ind['record_id'] : 0;
            $pid = isset($ind['parent_id']) ? (int) $ind['parent_id'] : 0;

            if ($cat === 'staff') {
                if ($rid <= 0) {
                    throw new Exception('individual staff requires record_id > 0');
                }
                if (!$mysqli->query("INSERT INTO share_content_for (staff_id, share_content_id) VALUES ($rid, $share_id)")) {
                    throw new Exception('share_content_for insert failed: ' . $mysqli->error);
                }
            } elseif ($cat === 'student') {
                if ($rid <= 0) {
                    throw new Exception('individual student requires record_id > 0');
                }
                if (!$mysqli->query("INSERT INTO share_content_for (student_id, share_content_id) VALUES ($rid, $share_id)")) {
                    throw new Exception('share_content_for insert failed: ' . $mysqli->error);
                }
            } elseif ($cat === 'parent') {
                if ($pid <= 0) {
                    throw new Exception('individual parent requires parent_id > 0');
                }
                if (!$mysqli->query("INSERT INTO share_content_for (user_parent_id, share_content_id) VALUES ($pid, $share_id)")) {
                    throw new Exception('share_content_for insert failed: ' . $mysqli->error);
                }
            } elseif ($cat === 'student_guardian') {
                if ($rid <= 0 || $pid <= 0) {
                    throw new Exception('student_guardian requires record_id and parent_id');
                }
                if (!$mysqli->query("INSERT INTO share_content_for (student_id, share_content_id) VALUES ($rid, $share_id)")) {
                    throw new Exception('share_content_for insert failed: ' . $mysqli->error);
                }
                if (!$mysqli->query("INSERT INTO share_content_for (user_parent_id, share_content_id) VALUES ($pid, $share_id)")) {
                    throw new Exception('share_content_for insert failed: ' . $mysqli->error);
                }
            } else {
                throw new Exception('Unknown individual category: ' . $cat);
            }
        }
    }

    $mysqli->commit();
    $mysqli->close();

    $out = [
        'success' => true,
        'share_id' => $share_id,
        'message' => 'Content shared successfully.',
        'created_by_used' => $created_by,
        'created_by_resolver_note' => $resolved['note'],
    ];

    if ($send_to === 'public') {
        $key = dc_share_encrypt_id($share_id);
        if ($key !== '') {
            $out['shared_url'] = rtrim(dc_share_base_url(), '/') . '/site/share/' . rawurlencode($key);
        }
    }

    dc_share_send_json($out);
} catch (Exception $e) {
    if ($mysqli) {
        @$mysqli->rollback();
        @$mysqli->close();
    }
    dc_share_send_json(['success' => false, 'error' => $e->getMessage()]);
}
