from generatorPreProcessor import GeneratorPreProcessor

def preprocessor(attributes=None, fullConfig=None):

    g = GeneratorPreProcessor(attributes,fullConfig)
    g('name').isRequired()
    g('zones').isOptional()
    g('bucket').isOptional()

    ge=g.getExpandedAttributes()
    if 'bucket' in ge:
      g('cos_instance').expandWith('cos[0]').isRequired()

    if 'services' in ge:
      if 'openshift' in ge['services']:
        g('services.openshift.version').isRequired()
        g('services.openshift.os').mustBeOneOf(['RHCOS', 'RHEL8'])
      if 'storage' in ge['services.openshift']:
        g('services.openshift.storage.version').isRequired()
        g('services.openshift.storage.device_path').isRequired()
        g('services.openshift.storage.template').mustBeOneOf(['odf-local'])

    result = {
      'attributes_updated': g.getExpandedAttributes(),
      'errors': g.getErrors()
    }
    return result
