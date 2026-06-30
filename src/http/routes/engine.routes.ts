import { Router, type Router as ExpressRouter } from 'express';

import * as engineController from '../controllers/engine.controller';

const router: ExpressRouter = Router();

router.get('/health', engineController.health);
router.get('/status', engineController.status);
router.get('/livez', engineController.livez);
router.get('/readyz', engineController.readyz);

export default router;
