    m_enabledPlugins = globalConfig.readEntry("Plugins", KIO::PreviewJob::defaultPlugins());

    KIO::PreviewJob* job = new KIO::PreviewJob(itemSubSet, cacheSize, &m_enabledPlugins);
    job->setIgnoreMaximumSize(itemSubSet.first().isLocalFile());
    connect(job,  &KIO::PreviewJob::gotPreview,
            this, &KFileItemModelRolesUpdater::slotGotPreview);
    connect(job,  &KIO::PreviewJob::failed,
            this, &KFileItemModelRolesUpdater::slotPreviewFailed);
    connect(job,  &KIO::PreviewJob::finished,
            this, &KFileItemModelRolesUpdater::slotPreviewJobFinished);
    m_previewJob = job;
