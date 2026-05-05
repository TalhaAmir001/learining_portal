<?php
/**
 * Create / update an announcement post (admin).
 *
 * multipart/form-data:
 * - api_secret (optional, if AC_API_SECRET set)
 * - id (optional int)
 * - class_id (int)
 * - section_id (int)
 * - title (string optional)
 * - body (string optional)
 * - is_published (0/1)
 * - media_choice: none|image|video_upload|video_embed
 * - embed_provider: youtube|loom (for video_embed)
 * - embed_url (for video_embed)
 * - media_file (for image/video_upload)
 */
require_once __DIR__ . '/ac_admin_bootstrap.php';

function ann_normalize_embed_url($provider, $url) {
    $url = trim((string) $url);
    if ($url === '') return null;
    $provider = strtolower(trim((string) $provider));
    if ($provider === 'youtube') {
        if (preg_match('~(?:youtube\.com/embed/|youtu\.be/)([a-zA-Z0-9_-]{6,})~', $url, $m)) {
            return 'https://www.youtube.com/embed/' . $m[1];
        }
        if (preg_match('~[?&]v=([a-zA-Z0-9_-]{6,})~', $url, $m)) {
            return 'https://www.youtube.com/embed/' . $m[1];
        }
        return null;
    }
    if ($provider === 'loom') {
        if (preg_match('~loom\.com/embed/([a-zA-Z0-9_-]+)~', $url, $m)) {
            return 'https://www.loom.com/embed/' . $m[1];
        }
        if (preg_match('~loom\.com/share/([a-zA-Z0-9_-]+)~', $url, $m)) {
            return 'https://www.loom.com/embed/' . $m[1];
        }
        return null;
    }
    return null;
}

function ann_handle_upload($field, $allowed_ext, $subdir) {
    if (empty($_FILES[$field]['name']) || $_FILES[$field]['error'] !== UPLOAD_ERR_OK) {
        return false;
    }
    $name = $_FILES[$field]['name'];
    $ext = strtolower(pathinfo($name, PATHINFO_EXTENSION));
    if (!in_array($ext, $allowed_ext, true)) {
        return false;
    }
    $upload_dir = __DIR__ . '/../Portal 2/uploads/' . $subdir . '/';
    if (!is_dir($upload_dir)) {
        @mkdir($upload_dir, 0755, true);
    }
    $new_name = 'af_' . time() . '_' . mt_rand(100000, 999999) . '.' . $ext;
    $dest = $upload_dir . $new_name;
    if (!move_uploaded_file($_FILES[$field]['tmp_name'], $dest)) {
        return false;
    }
    return 'uploads/' . $subdir . '/' . $new_name;
}

function ann_unlink_file($relative) {
    $relative = (string) $relative;
    if ($relative === '' || strpos($relative, '..') !== false) return;
    $path = __DIR__ . '/../Portal 2/' . $relative;
    if (is_file($path)) {
        @unlink($path);
    }
}

$mysqli = null;
try {
    $mysqli = ac_mysqli_connect();
    ac_require_api_secret(array_merge($_POST, array()));

    $session_id = ac_current_session_id($mysqli);
    if ($session_id <= 0) throw new Exception('Could not resolve current session.');

    $id = isset($_POST['id']) ? (int) $_POST['id'] : 0;
    $class_id = isset($_POST['class_id']) ? (int) $_POST['class_id'] : 0;
    $section_id = isset($_POST['section_id']) ? (int) $_POST['section_id'] : 0;
    $title = isset($_POST['title']) ? trim((string) $_POST['title']) : '';
    $body = isset($_POST['body']) ? trim((string) $_POST['body']) : '';
    $is_published = isset($_POST['is_published']) ? (int) $_POST['is_published'] : 1;
    $media_choice = isset($_POST['media_choice']) ? trim((string) $_POST['media_choice']) : 'none';
    $embed_provider = isset($_POST['embed_provider']) ? trim((string) $_POST['embed_provider']) : '';
    $embed_input = isset($_POST['embed_url']) ? trim((string) $_POST['embed_url']) : '';

    if ($class_id < 1 || $section_id < 1) {
        throw new Exception('Please select class and section.');
    }

    $existing = null;
    if ($id > 0) {
        $r = $mysqli->query('SELECT * FROM announcement_posts WHERE id=' . (int) $id . ' AND session_id=' . (int) $session_id . ' LIMIT 1');
        if ($r && $r->num_rows > 0) {
            $existing = $r->fetch_assoc();
        } else {
            throw new Exception('Announcement not found.');
        }
    }

    $now = date('Y-m-d H:i:s');
    $media_type = 'none';
    $embed_url = null;
    $embed_provider_out = null;
    $media_path = null;

    if ($media_choice === 'image') {
        if (!empty($_FILES['media_file']['name'])) {
            $up = ann_handle_upload('media_file', array('jpg', 'jpeg', 'png', 'gif', 'webp'), 'announcement_feed/images');
            if ($up === false) throw new Exception('Image upload failed or invalid type.');
            if ($existing && !empty($existing['media_path']) && $existing['media_path'] !== $up) {
                ann_unlink_file($existing['media_path']);
            }
            $media_path = $up;
            $media_type = 'image';
        } elseif ($existing && $existing['media_type'] === 'image' && !empty($existing['media_path'])) {
            $media_type = 'image';
            $media_path = $existing['media_path'];
        }
    } elseif ($media_choice === 'video_upload') {
        if (!empty($_FILES['media_file']['name'])) {
            $up = ann_handle_upload('media_file', array('mp4', 'webm', 'ogg'), 'announcement_feed/videos');
            if ($up === false) throw new Exception('Video upload failed or invalid type.');
            if ($existing && !empty($existing['media_path']) && $existing['media_path'] !== $up) {
                ann_unlink_file($existing['media_path']);
            }
            $media_path = $up;
            $media_type = 'video_upload';
        } elseif ($existing && $existing['media_type'] === 'video_upload' && !empty($existing['media_path'])) {
            $media_type = 'video_upload';
            $media_path = $existing['media_path'];
        }
    } elseif ($media_choice === 'video_embed') {
        $provider = strtolower(trim((string) $embed_provider));
        if (!in_array($provider, array('youtube', 'loom'), true)) $provider = 'youtube';
        $normalized = ann_normalize_embed_url($provider, $embed_input);
        if ($normalized === null) throw new Exception('Invalid or unsupported video URL.');
        $media_type = 'video_embed';
        $embed_provider_out = $provider;
        $embed_url = $normalized;
        if ($existing && !empty($existing['media_path'])) {
            ann_unlink_file($existing['media_path']);
        }
    } else {
        // none: remove existing media (if any)
        if ($existing && !empty($existing['media_path'])) {
            ann_unlink_file($existing['media_path']);
        }
    }

    $title_sql = $title === '' ? 'NULL' : "'" . $mysqli->real_escape_string($title) . "'";
    $body_sql = $body === '' ? 'NULL' : "'" . $mysqli->real_escape_string($body) . "'";
    $media_type_esc = $mysqli->real_escape_string($media_type);
    $embed_provider_sql = $embed_provider_out ? "'" . $mysqli->real_escape_string($embed_provider_out) . "'" : 'NULL';
    $embed_url_sql = $embed_url ? "'" . $mysqli->real_escape_string($embed_url) . "'" : 'NULL';
    $media_path_sql = $media_path ? "'" . $mysqli->real_escape_string($media_path) . "'" : 'NULL';
    $is_pub = $is_published ? 1 : 0;

    if ($id > 0) {
        $sql = "UPDATE announcement_posts SET
            class_id=" . (int) $class_id . ",
            section_id=" . (int) $section_id . ",
            title=" . $title_sql . ",
            body=" . $body_sql . ",
            media_type='" . $media_type_esc . "',
            embed_provider=" . $embed_provider_sql . ",
            embed_url=" . $embed_url_sql . ",
            media_path=" . $media_path_sql . ",
            is_published=" . $is_pub . ",
            updated_at='" . $mysqli->real_escape_string($now) . "'
            WHERE id=" . (int) $id . " AND session_id=" . (int) $session_id . "
            LIMIT 1";
        if (!$mysqli->query($sql)) throw new Exception('Update failed: ' . $mysqli->error);
        $mysqli->close();
        ac_admin_success(array('id' => $id));
        return;
    }

    // Insert
    $staff_id = isset($_POST['created_by_staff_id']) ? (int) $_POST['created_by_staff_id'] : 0;
    $staff_id_sql = $staff_id > 0 ? (string) $staff_id : 'NULL';

    $sql = "INSERT INTO announcement_posts
        (session_id, class_id, section_id, title, body, media_type, embed_provider, embed_url, media_path, created_by_staff_id, created_at, updated_at, is_published)
        VALUES (
            " . (int) $session_id . ",
            " . (int) $class_id . ",
            " . (int) $section_id . ",
            " . $title_sql . ",
            " . $body_sql . ",
            '" . $media_type_esc . "',
            " . $embed_provider_sql . ",
            " . $embed_url_sql . ",
            " . $media_path_sql . ",
            " . $staff_id_sql . ",
            '" . $mysqli->real_escape_string($now) . "',
            '" . $mysqli->real_escape_string($now) . "',
            " . $is_pub . "
        )";
    if (!$mysqli->query($sql)) throw new Exception('Insert failed: ' . $mysqli->error);
    $new_id = (int) $mysqli->insert_id;

    $mysqli->close();
    ac_admin_success(array('id' => $new_id));
} catch (Exception $e) {
    if ($mysqli) $mysqli->close();
    ac_admin_fail($e->getMessage());
}

