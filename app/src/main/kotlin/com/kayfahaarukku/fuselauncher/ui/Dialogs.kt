package com.kayfahaarukku.fuselauncher.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CreateNewFolder
import androidx.compose.material.icons.rounded.Folder
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.kayfahaarukku.fuselauncher.apps.AppListSortType
import com.kayfahaarukku.fuselauncher.apps.PinnedAppsSortType
import com.kayfahaarukku.fuselauncher.data.Folder

private fun AppListSortType.label() = when (this) {
    AppListSortType.ALPHABETICAL_ASC -> "Alphabetical (A to Z)"
    AppListSortType.ALPHABETICAL_DESC -> "Reverse alphabetical (Z to A)"
    AppListSortType.USAGE -> "Usage frequency"
}

private fun PinnedAppsSortType.label() = when (this) {
    PinnedAppsSortType.ALPHABETICAL_ASC -> "Alphabetical (A to Z)"
    PinnedAppsSortType.ALPHABETICAL_DESC -> "Reverse alphabetical (Z to A)"
    PinnedAppsSortType.USAGE -> "Usage frequency"
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SortSheet(
    appListSort: AppListSortType,
    pinnedSort: PinnedAppsSortType,
    onAppListSort: (AppListSortType) -> Unit,
    onPinnedSort: (PinnedAppsSortType) -> Unit,
    onDismiss: () -> Unit,
) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            Modifier
                .navigationBarsPadding()
                .verticalScroll(rememberScrollState()),
        ) {
            SheetHeader("Sort app list")
            AppListSortType.entries.forEach { sort ->
                RadioRow(sort.label(), sort == appListSort) { onAppListSort(sort) }
            }
            SheetHeader("Sort pinned apps")
            PinnedAppsSortType.entries.forEach { sort ->
                RadioRow(sort.label(), sort == pinnedSort) { onPinnedSort(sort) }
            }
        }
    }
}

@Composable
private fun SheetHeader(text: String) = Text(
    text,
    style = MaterialTheme.typography.titleSmall,
    color = MaterialTheme.colorScheme.primary,
    modifier = Modifier.padding(start = 20.dp, top = 16.dp, bottom = 4.dp),
)

@Composable
private fun RadioRow(label: String, selected: Boolean, onClick: () -> Unit) = Row(
    verticalAlignment = Alignment.CenterVertically,
    modifier = Modifier
        .fillMaxWidth()
        .clickable(onClick = onClick)
        .padding(horizontal = 12.dp, vertical = 4.dp),
) {
    RadioButton(selected = selected, onClick = onClick)
    Text(label, style = MaterialTheme.typography.bodyLarge)
}

/** Pick an existing folder for an app, or start a new one. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MoveToFolderSheet(
    folders: List<Folder>,
    onPick: (Folder) -> Unit,
    onCreateNew: () -> Unit,
    onDismiss: () -> Unit,
) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            Modifier
                .navigationBarsPadding()
                .heightIn(max = 480.dp)
                .verticalScroll(rememberScrollState()),
        ) {
            SheetHeader("Move to folder")
            ListItem(
                headlineContent = { Text("New folder") },
                leadingContent = { Icon(Icons.Outlined.CreateNewFolder, null) },
                colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                modifier = Modifier.clickable(onClick = onCreateNew),
            )
            folders.forEach { folder ->
                ListItem(
                    headlineContent = { Text(folder.name) },
                    supportingContent = { Text("${folder.packageNames.size} apps") },
                    leadingContent = { Icon(Icons.Rounded.Folder, null) },
                    colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                    modifier = Modifier.clickable { onPick(folder) },
                )
            }
        }
    }
}

/** Shared by "new folder" and "rename folder"; [initial] seeds the field. */
@Composable
fun FolderNameDialog(
    title: String,
    initial: String = "",
    onConfirm: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    var name by remember { mutableStateOf(initial) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("Folder name") },
                singleLine = true,
            )
        },
        confirmButton = {
            TextButton(
                onClick = { onConfirm(name.trim()) },
                enabled = name.isNotBlank(),
            ) { Text("Save") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

@Composable
fun ConfirmDialog(
    title: String,
    message: String,
    confirmLabel: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) = AlertDialog(
    onDismissRequest = onDismiss,
    title = { Text(title) },
    text = { Text(message) },
    confirmButton = { TextButton(onClick = onConfirm) { Text(confirmLabel) } },
    dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
)
