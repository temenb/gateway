import { Router, type Router as ExpressRouter } from 'express';

import * as profileController from '../controllers/profile.controller';

const router: ExpressRouter = Router();


router.get('/health', profileController.health);
router.get('/status', profileController.status);
router.get('/livez', profileController.livez);
router.get('/readyz', profileController.readyz);

router.get('/getMyProfile', profileController.getMyProfile);
router.get('/getProfile', profileController.getProfile);

export default router;
