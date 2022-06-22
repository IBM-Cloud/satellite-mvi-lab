from generatorPreProcessor import GeneratorPreProcessor

def preprocessor(attributes=None, fullConfig=None):

    g = GeneratorPreProcessor(attributes,fullConfig)
    g('name').isRequired()
    g('zones').isOptional()
    g('bucket').isOptional()

    ge=g.getExpandedAttributes()
    if 'bucket' in ge:
        g('cos_instance').expandWith('cos[0]').isRequired()

    result = {
        'attributes_updated': g.getExpandedAttributes(),
        'errors': g.getErrors()
    }
    return result
